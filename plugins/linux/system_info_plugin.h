// Linux system info — not compiled; Linux uses dart:io (read /proc/).
// This file exists for directory structure consistency across platforms.

#pragma once

#include <string>

std::string GetSystemInfoJson();
