cmake_minimum_required(VERSION 3.14)
project(flutter_showcase LANGUAGES CXX)

set(BINARY_NAME "flutter_showcase")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")
set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)

add_subdirectory(${FLUTTER_MANAGED_DIR})

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

add_definitions(-DAPPLICATION_ID="${CMAKE_PROJECT_NAME}")

add_executable(${BINARY_NAME}
  "${CMAKE_CURRENT_SOURCE_DIR}/runner/main.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/runner/my_application.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/runner/plugins/system_info/system_info_plugin.cc"
)
apply_standard_settings(${BINARY_NAME})
target_include_directories(${BINARY_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/runner/plugins/system_info"
)
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
add_dependencies(${BINARY_NAME} flutter_assemble)

install(TARGETS ${BINARY_NAME} DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)
