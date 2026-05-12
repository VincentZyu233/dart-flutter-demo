from pathlib import Path

app_delegate = Path("macos/Runner/AppDelegate.swift")
plugin = Path("plugins/macos/SystemInfoPlugin.swift")
text = app_delegate.read_text(encoding="utf-8")

for import_line in ["import Foundation", "import Darwin"]:
    if import_line not in text:
        text = text.replace(
            "import FlutterMacOS", f"import FlutterMacOS\n{import_line}"
        )

# Remove any registration code we might have previously injected
for old_pattern in [
    "GeneratedPluginRegistrant.register(with: self)\n    SystemInfoPlugin.register(with: self)",
    "SystemInfoPlugin.register(with: self)",
    "SystemInfoPlugin.register(with: systemInfoRegistrar)",
]:
    if old_pattern in text:
        text = text.replace(old_pattern, "")

# Remove applicationDidFinishLaunching override if we injected it
import re

text = re.sub(
    r"\n    override func applicationDidFinishLaunching\(_ notification: Notification\) \{\n"
    r'        let systemInfoRegistrar = self\.registrar\(forPlugin: "SystemInfoPlugin"\)\n'
    r"        SystemInfoPlugin\.register\(with: systemInfoRegistrar\)\n"
    r"        super\.applicationDidFinishLaunching\(notification\)\n"
    r"    \}",
    "",
    text,
)
text = re.sub(
    r"\n    override func applicationDidFinishLaunching\(_ notification: Notification\) \{\n"
    r"        SystemInfoPlugin\.register\(with: self\)\n"
    r"        super\.applicationDidFinishLaunching\(notification\)\n"
    r"    \}",
    "",
    text,
)

# Inline inject plugin source code
if "public class SystemInfoPlugin: NSObject, FlutterPlugin" not in text:
    plugin_text = plugin.read_text(encoding="utf-8")
    plugin_lines = [
        line for line in plugin_text.splitlines() if not line.startswith("import ")
    ]
    plugin_text = "\n".join(plugin_lines).strip()
    text = text.rstrip() + "\n\n" + plugin_text

app_delegate.write_text(text, encoding="utf-8")

# Register SystemInfoPlugin via GeneratedPluginRegistrant.swift
registrant_path = Path("macos/Flutter/GeneratedPluginRegistrant.swift")
if registrant_path.exists():
    registrant_text = registrant_path.read_text(encoding="utf-8")
    if "SystemInfoPlugin.register(with:" not in registrant_text:
        # Add our plugin registration before the closing brace of the register method
        registrant_text = registrant_text.replace(
            "  }\n}",
            '    SystemInfoPlugin.register(with: registry.registrar(forPlugin: "SystemInfoPlugin"))\n  }\n}',
        )
        registrant_path.write_text(registrant_text, encoding="utf-8")
