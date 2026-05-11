from pathlib import Path
import re

app_delegate = Path("ios/Runner/AppDelegate.swift")
plugin = Path("plugins/ios/SystemInfoPlugin.swift")
text = app_delegate.read_text(encoding="utf-8")

for import_line in ["import Foundation", "import UIKit"]:
    if import_line not in text:
        text = text.replace("import Flutter", f"import Flutter\n{import_line}")

if "SystemInfoPlugin.register(with:" not in text:
    text = text.replace(
        "GeneratedPluginRegistrant.register(with: self)",
        "GeneratedPluginRegistrant.register(with: self)\n"
        '    let systemInfoRegistrar = self.registrar(forPlugin: "SystemInfoPlugin")\n'
        "    SystemInfoPlugin.register(with: systemInfoRegistrar)",
    )

if "public class SystemInfoPlugin: NSObject, FlutterPlugin" not in text:
    plugin_text = plugin.read_text(encoding="utf-8")
    plugin_lines = [
        line for line in plugin_text.splitlines() if not line.startswith("import ")
    ]
    plugin_text = "\n".join(plugin_lines).strip()
    text = text.rstrip() + "\n\n" + plugin_text

app_delegate.write_text(text, encoding="utf-8")

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
