# Windows: patch CMakeLists.txt to include system_info plugin source, include dir, and export flags
cmake_path = "windows/runner/CMakeLists.txt"
with open(cmake_path, "r") as f:
    cmake = f.read()

plugin_src = '  "runner/plugins/system_info/system_info_plugin.cpp"'
include_dir = '  "${CMAKE_CURRENT_SOURCE_DIR}/plugins/system_info"'
export_flags = "target_link_options(${BINARY_NAME} PRIVATE /EXPORT:GetSystemInfoJson /EXPORT:FreeSystemInfoJson)"

if plugin_src not in cmake:
    cmake = cmake.replace(
        '"runner/win32_window.cpp"', '"runner/win32_window.cpp"\n' + plugin_src
    )

if include_dir not in cmake:
    cmake = cmake.replace(
        "target_include_directories(${BINARY_NAME} PRIVATE",
        "target_include_directories(${BINARY_NAME} PRIVATE\n" + include_dir,
    )

if export_flags not in cmake:
    cmake = cmake.replace(
        "target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_plugin)",
        "target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_plugin)\n\n"
        + export_flags,
    )

with open(cmake_path, "w") as f:
    f.write(cmake)
