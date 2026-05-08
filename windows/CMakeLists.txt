cmake_minimum_required(VERSION 3.14)
project(flutter_showcase LANGUAGES CXX)

set(BINARY_NAME "flutter_showcase")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN")
set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)

include(${FLUTTER_MANAGED_DIR})

add_subdirectory(${FLUTTER_MANAGED_DIR})

add_executable(${BINARY_NAME} WIN32
  "${CMAKE_CURRENT_SOURCE_DIR}/runner/main.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/runner/flutter_window.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/runner/utils.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/runner/win32_window.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/runner/plugins/system_info/system_info_plugin.cpp"
)

apply_standard_settings(${BINARY_NAME})
target_include_directories(${BINARY_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/runner/plugins/system_info"
)
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_plugin
  user32 psapi kernel32 iphlpapi ws2_32)
target_link_libraries(${BINARY_NAME} PRIVATE "${FLUTTER_MANAGED_DIR}/flutter_export.h")
add_dependencies(${BINARY_NAME} flutter_assemble)

install(TARGETS ${BINARY_NAME} DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)
