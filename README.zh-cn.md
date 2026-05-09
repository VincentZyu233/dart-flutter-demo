# Flutter Showcase

一个面向 Android、Windows 和 Linux 的跨平台 Flutter UI 展示 PoC（Proof of Concept）应用。

## 页面介绍

### 0. 系统信息实验室

通过原生 C++（Windows）与 Kotlin（Android）集成，以及 Linux 上的 dart:io 获取系统信息。展示 OS、主机名、内核、运行时间、CPU、内存、磁盘和本地 IP。内置调试日志展开面板，可直接查看采集链路并导出诊断信息。

### 1. 经典对话框实验室

像素级复刻经典 Win32 对话框。使用复古边框、内凹输入框样式和时代感配色，证明 Flutter 不依赖系统原生控件，也可以还原非现代默认风格的界面规范。

### 2. 文字排版工作室

一个交互式文字实验场。通过实时控件调整字号、字间距和行高。在系统字体与 Google Fonts 自定义衬线字体之间切换。适合检查文字渲染、间距控制和整体节奏感。

### 3. 响应式布局挑战

一个由 `LayoutBuilder` 驱动的响应式卡片网格。会根据可用宽度自动切换 1 列、2 列或 3 列。适合验证桌面窗口缩放行为，以及不同设备尺寸下的布局适配效果。

### 4. 控件与反馈实验室

一个用于交互控件与反馈模式的紧凑实验页。包含单选框、多选框、开关、进度指示器、SnackBar 和 BottomSheet。适合检查状态切换、动效反馈与组件响应性。

## 构建与运行

```bash
# 安装依赖
flutter pub get

# 调试模式运行
flutter run

# Release 构建
flutter build windows --release
flutter build linux --release
flutter build apk --release
```

## CI/CD

GitHub Actions 负责自动构建与打包。提交信息包含 `build action` 或 `build release` 即可触发流水线。详见 [build.zh-cn.md](.github/workflows/build.zh-cn.md)。

## 技术栈

- Flutter（stable 通道）
- Material 3 设计系统
- Google Fonts 插件
- 状态管理：setState（刻意保持 PoC 的简单性）
