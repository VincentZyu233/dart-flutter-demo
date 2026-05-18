from pathlib import Path
import plistlib
import re

# iOS: inject SystemInfoPlugin.swift into AppDelegate.swift, register via registrar(forPlugin:),
#      and force unsigned Xcode settings for CI builds
app_delegate = Path("ios/Runner/AppDelegate.swift")
plugin = Path("plugins/ios/SystemInfoPlugin.swift")
text = app_delegate.read_text(encoding="utf-8")

for import_line in ["import Foundation", "import UIKit"]:
    if import_line not in text:
        text = text.replace("import Flutter", f"import Flutter\n{import_line}")

# Remove any registration code we might have previously injected into AppDelegate
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

# Remove didFinishLaunchingWithOptions override if we injected it (old approach)
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

# Add SystemInfoPlugin registration in didInitializeImplicitFlutterEngine if it exists
# New Flutter 3.41+ template uses @main with FlutterImplicitEngineDelegate
if "didInitializeImplicitFlutterEngine" in text:
    if "SystemInfoPlugin.register(with:" not in text:
        text = text.replace(
            "GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)",
            "GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)\n"
            '        SystemInfoPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "SystemInfoPlugin")!)',
        )
elif "GeneratedPluginRegistrant.register(with: self)" in text:
    # Old Flutter template: add registration after existing one
    if "SystemInfoPlugin.register(with:" not in text:
        text = text.replace(
            "GeneratedPluginRegistrant.register(with: self)",
            "GeneratedPluginRegistrant.register(with: self)\n"
            '    let systemInfoRegistrar = self.registrar(forPlugin: "SystemInfoPlugin")\n'
            "    SystemInfoPlugin.register(with: systemInfoRegistrar)",
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

# Set iOS display name
plist_path = "ios/Runner/Info.plist"
with open(plist_path, "rb") as f:
    plist = plistlib.load(f)
plist["CFBundleDisplayName"] = "DartFlutterDemo"
plist["CFBundleName"] = "DartFlutterDemo"
with open(plist_path, "wb") as f:
    plistlib.dump(plist, f)

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
