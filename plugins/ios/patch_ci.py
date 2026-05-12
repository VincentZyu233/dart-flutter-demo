from pathlib import Path
import re

app_delegate = Path("ios/Runner/AppDelegate.swift")
plugin = Path("plugins/ios/SystemInfoPlugin.swift")
text = app_delegate.read_text(encoding="utf-8")

for import_line in ["import Foundation", "import UIKit"]:
    if import_line not in text:
        text = text.replace("import Flutter", f"import Flutter\n{import_line}")

# Remove any registration code we might have previously injected
for old_pattern in [
    "GeneratedPluginRegistrant.register(with: self)\n"
    '    let systemInfoRegistrar = self.registrar(forPlugin: "SystemInfoPlugin")\n'
    "    SystemInfoPlugin.register(with: systemInfoRegistrar)",
    "GeneratedPluginRegistrant.register(with: self)\n    SystemInfoPlugin.register(with: self)",
    "SystemInfoPlugin.register(with: self)",
    "SystemInfoPlugin.register(with: systemInfoRegistrar)",
]:
    if old_pattern in text:
        text = text.replace(old_pattern, "")

# Remove didFinishLaunchingWithOptions override if we injected it
text = re.sub(
    r"\n    override func application\(\n"
    r"        _ application: UIApplication,\n"
    r"        didFinishLaunchingWithOptions launchOptions: \[UIApplication\.LaunchOptionsKey: Any\]\?\n"
    r"    \) -> Bool \{\n"
    r'        let systemInfoRegistrar = self\.registrar\(forPlugin: "SystemInfoPlugin"\)\n'
    r"        SystemInfoPlugin\.register\(with: systemInfoRegistrar\)\n"
    r"        return super\.application\(application, didFinishLaunchingWithOptions: launchOptions\)\n"
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
registrant_path = Path("ios/Flutter/GeneratedPluginRegistrant.swift")
if registrant_path.exists():
    registrant_text = registrant_path.read_text(encoding="utf-8")
    if "SystemInfoPlugin.register(with:" not in registrant_text:
        # Add our plugin registration before the closing brace of the register method
        registrant_text = registrant_text.replace(
            "  }\n}",
            '    SystemInfoPlugin.register(with: registry.registrar(forPlugin: "SystemInfoPlugin"))\n  }\n}',
        )
        registrant_path.write_text(registrant_text, encoding="utf-8")

# Force unsigned build settings in Xcode project and xcconfig
pbxproj = Path("ios/Runner.xcodeproj/project.pbxproj")
text = pbxproj.read_text(encoding="utf-8")
replacements = [
    (r"CODE_SIGN_STYLE = Automatic;", "CODE_SIGN_STYLE = Manual;"),
    (r"CODE_SIGN_STYLE = Apple Development;", "CODE_SIGN_STYLE = Manual;"),
    (r"CODE_SIGNING_ALLOWED = YES;", "CODE_SIGNING_ALLOWED = NO;"),
    (r"CODE_SIGNING_REQUIRED = YES;", "CODE_SIGNING_REQUIRED = NO;"),
    (r"DEVELOPMENT_TEAM = [^;]*;", 'DEVELOPMENT_TEAM = "";'),
    (
        r"PROVISIONING_PROFILE_SPECIFIER = [^;]*;",
        'PROVISIONING_PROFILE_SPECIFIER = "";',
    ),
]
for pattern, replacement in replacements:
    text = re.sub(pattern, replacement, text)
pbxproj.write_text(text, encoding="utf-8")

xcconfig = Path("ios/Flutter/Release.xcconfig")
xcconfig.write_text(
    '#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"\n'
    '#include "Generated.xcconfig"\n'
    "CODE_SIGN_IDENTITY=\n"
    "CODE_SIGNING_REQUIRED=NO\n"
    "CODE_SIGNING_ALLOWED=NO\n"
    "CODE_SIGN_STYLE=Manual\n"
    "DEVELOPMENT_TEAM=\n"
    "PROVISIONING_PROFILE_SPECIFIER=\n",
    encoding="utf-8",
)
