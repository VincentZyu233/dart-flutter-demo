#include "win32_window.h"

#pragma warning(disable : 4996)

#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"

namespace {

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

HMODULE GetUser32Module() {
  static const HMODULE module = ::GetModuleHandle(L"user32.dll");
  return module;
}

EnableNonClientDpiScaling* GetEnableNonClientDpiScaling() {
  static const auto func = reinterpret_cast<EnableNonClientDpiScaling*>(
      ::GetProcAddress(GetUser32Module(), "EnableNonClientDpiScaling"));
  return func;
}

}  // namespace

class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() {
    if (class_registered_) {
      ::UnregisterClass(kWindowClassName, nullptr);
    }
  }

  LPCWSTR RegisterWindowClass() {
    if (!class_registered_) {
      WNDCLASS window_class{};
      window_class.hCursor = ::LoadCursor(nullptr, IDC_ARROW);
      window_class.lpszClassName = kWindowClassName;
      window_class.style = CS_HREDRAW | CS_VREDRAW;
      window_class.cbClsExtra = 0;
      window_class.cbWndExtra = 0;
      window_class.hInstance = ::GetModuleHandle(nullptr);
      window_class.hIcon =
          ::LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
      window_class.hbrBackground = 0;
      window_class.lpszMenuName = nullptr;
      window_class.lpfnWndProc = Win32Window::WndProc;
      registered_class_ = ::RegisterClass(&window_class);
      class_registered_ = true;
    }
    return kWindowClassName;
  }

  static WindowClassRegistrar* GetInstance() {
    static auto* const instance = new WindowClassRegistrar();
    return instance;
  }

 private:
  WindowClassRegistrar() = default;
  bool class_registered_ = false;
  ATOM registered_class_ = 0;
};

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin, const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->RegisterWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = ::CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, ::GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  auto* enable_non_client_dpi_scaling = GetEnableNonClientDpiScaling();
  if (enable_non_client_dpi_scaling) {
    enable_non_client_dpi_scaling(window);
  }

  return OnCreate();
}

bool Win32Window::Show() {
  return ::ShowWindow(window_handle_, SW_SHOWNORMAL);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    ::DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  ::SetParent(content, window_handle_);
  ::SetWindowPos(content, nullptr, 0, 0,
                 ::GetSystemMetrics(SM_CXSCREEN),
                 ::GetSystemMetrics(SM_CYSCREEN),
                 SWP_NOACTIVATE | SWP_NOZORDER);
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  ::GetClientRect(window_handle_, &frame);
  return frame;
}

bool Win32Window::OnCreate() {
  return true;
}

void Win32Window::OnDestroy() {}

LRESULT
Win32Window::WndProc(HWND const window, UINT const message,
                     WPARAM const wparam, LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto* window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto* that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd, UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      if (quit_on_close_ && g_active_window_count == 0) {
        ::PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto* rect = reinterpret_cast<RECT*>(lparam);
      ::SetWindowPos(hwnd, nullptr, rect->left, rect->top,
                     rect->right - rect->left, rect->bottom - rect->top,
                     SWP_NOZORDER | SWP_NOACTIVATE);
      return 0;
    }

    case WM_THEMECHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::UpdateTheme(HWND const window) {
  BOOL dark_mode_enabled = FALSE;
  DWORD os_version = ::GetVersion();
  if (os_version < 0x0602 && ::GetVersion() < 0x0602) {
    return;
  }

  HKEY key = nullptr;
  if (::RegOpenKeyEx(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                     0, KEY_READ, &key) != ERROR_SUCCESS) {
    return;
  }

  DWORD value = 0;
  DWORD size = sizeof(value);
  auto result = ::RegQueryValueEx(key, kGetPreferredBrightnessRegValue,
                                  nullptr, nullptr,
                                  reinterpret_cast<LPBYTE>(&value), &size);
  ::RegCloseKey(key);
  if (result == ERROR_SUCCESS) {
    dark_mode_enabled = value == 0;
  }

  ::DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &dark_mode_enabled, sizeof(dark_mode_enabled));
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

int Win32Window::Scale(unsigned int value, double scale_factor) {
  return static_cast<int>(value * scale_factor);
}
