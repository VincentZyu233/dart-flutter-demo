# Windows: patch CMakeLists.txt to include system_info plugin source and include dir
cmake_path = "windows/runner/CMakeLists.txt"
with open(cmake_path, "r") as f:
    cmake = f.read()

plugin_src = '  "runner/plugins/system_info/system_info_plugin.cpp"'
include_dir = '  "${CMAKE_CURRENT_SOURCE_DIR}/plugins/system_info"'

if plugin_src not in cmake:
    cmake = cmake.replace(
        '"runner/win32_window.cpp"', '"runner/win32_window.cpp"\n' + plugin_src
    )

if include_dir not in cmake:
    cmake = cmake.replace(
        "target_include_directories(${BINARY_NAME} PRIVATE",
        "target_include_directories(${BINARY_NAME} PRIVATE\n" + include_dir,
    )

with open(cmake_path, "w") as f:
    f.write(cmake)
