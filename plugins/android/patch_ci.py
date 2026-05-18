# Android: inject SystemInfoPlugin import + registration into MainActivity.kt
from pathlib import Path
import re

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
manifest_path = Path("android/app/src/main/AndroidManifest.xml")
manifest = manifest_path.read_text(encoding="utf-8")

manifest, count = re.subn(
    r'(<application\b[^>]*\bandroid:label=")[^"]*(")',
    r"\1DartFlutterDemo\2",
    manifest,
    count=1,
)
if count == 0:
    manifest, count = re.subn(
        r"(<application\b)([^>]*?)>",
        r'\1\2 android:label="DartFlutterDemo">',
        manifest,
        count=1,
    )
    if count == 0:
        raise RuntimeError("Failed to set android:label in AndroidManifest.xml")

manifest_path.write_text(manifest, encoding="utf-8")
