# Android: inject SystemInfoPlugin import + registration into MainActivity.kt
import xml.etree.ElementTree as ET

kt_path = "android/app/src/main/kotlin/com/example/dart_flutter_demo/MainActivity.kt"
with open(kt_path, "r") as f:
    kt = f.read()

kt = kt.replace(
    "import io.flutter.embedding.android.FlutterActivity",
    "import com.example.dart_flutter_demo.SystemInfoPlugin\nimport io.flutter.embedding.android.FlutterActivity",
)
kt = kt.replace(
    "super.configureFlutterEngine(flutterEngine)",
    "super.configureFlutterEngine(flutterEngine)\n        flutterEngine.plugins.add(SystemInfoPlugin())",
)

with open(kt_path, "w") as f:
    f.write(kt)

# Set Android display name
NS = {"android": "http://schemas.android.com/apk/res/android"}
tree = ET.parse("android/app/src/main/AndroidManifest.xml")
tree.getroot().attrib["{" + NS["android"] + "}label"] = "DartFlutterDemo"
tree.write(
    "android/app/src/main/AndroidManifest.xml", xml_declaration=True, encoding="utf-8"
)
