#pragma once

#include <string>

extern "C" {
  __declspec(dllexport) char* GetSystemInfoJson();
  __declspec(dllexport) void FreeSystemInfoJson(char* str);
}
