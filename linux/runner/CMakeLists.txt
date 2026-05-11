cmake_minimum_required(VERSION 3.13)
set(BINARY_NAME "dart_flutter_demo")

set(APPLICATION_ID "com.example.dart_flutter_demo")

add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

apply_standard_settings(${BINARY_NAME})

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "APPLICATION_ID=\"${APPLICATION_ID}\"")
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
