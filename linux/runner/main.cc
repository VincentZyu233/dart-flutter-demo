#include "my_application.h"

#include "plugins/system_info/system_info_plugin.h"

int main(int argc, char** argv) {
  // Register native plugins before GTK init
  g_autoptr(FlPluginRegistrar) registrar =
      fl_plugin_registrar_get_default();
  flutter_showcase::SystemInfoPlugin::RegisterWithRegistrar(registrar);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
