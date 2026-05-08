// Linux system info — not compiled; Linux uses dart:io (read /proc/).
// This file exists for directory structure consistency across platforms.

#include "system_info_plugin.h"

std::string GetSystemInfoJson() {
  return "{}";
}
