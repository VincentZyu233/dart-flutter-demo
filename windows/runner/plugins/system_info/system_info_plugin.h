#pragma once

#include <string>

extern "C" {
  char* GetSystemInfoJson();
  void FreeSystemInfoJson(char* str);
}
