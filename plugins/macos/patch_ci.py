from pathlib import Path

app_delegate = Path("macos/Runner/AppDelegate.swift")
plugin = Path("plugins/macos/SystemInfoPlugin.swift")
text = app_delegate.read_text(encoding="utf-8")

for import_line in ["import Foundation", "import Darwin"]:
    if import_line not in text:
        text = text.replace(
            "import FlutterMacOS", f"import FlutterMacOS\n{import_line}"
        )

if "SystemInfoPlugin.register(with:" not in text:
    if "GeneratedPluginRegistrant.register(with: self)" in text:
        # Old Flutter: add registration after existing one
        text = text.replace(
            "GeneratedPluginRegistrant.register(with: self)",
            "GeneratedPluginRegistrant.register(with: self)\n"
            "    SystemInfoPlugin.register(with: self)",
        )
    else:
        # New Flutter (@main): add applicationDidFinishLaunching override
        registration = (
            "\n"
            "    override func applicationDidFinishLaunching(_ notification: Notification) {\n"
            "        SystemInfoPlugin.register(with: self)\n"
            "        super.applicationDidFinishLaunching(notification)\n"
            "    }\n"
        )
        text = text.replace(
            "class AppDelegate: FlutterAppDelegate {",
            "class AppDelegate: FlutterAppDelegate {" + registration,
        )

if "public class SystemInfoPlugin: NSObject, FlutterPlugin" not in text:
    plugin_text = plugin.read_text(encoding="utf-8")
    plugin_lines = [
        line for line in plugin_text.splitlines() if not line.startswith("import ")
    ]
    plugin_text = "\n".join(plugin_lines).strip()
    text = text.rstrip() + "\n\n" + plugin_text

app_delegate.write_text(text, encoding="utf-8")
