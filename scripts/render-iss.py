import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <version>", file=sys.stderr)
        sys.exit(1)

    version = sys.argv[1]
    build_dir = REPO_ROOT / "build" / "windows" / "x64" / "runner" / "Release"
    icon_file = REPO_ROOT / "assets" / "generated-icons" / "windows" / "app_icon.ico"
    template = REPO_ROOT / "windows" / "packaging" / "exe" / "inno_setup.iss"
    out_dir = REPO_ROOT / "dist"

    out_dir.mkdir(parents=True, exist_ok=True)

    subs = {
        "{{APP_ID}}": "C3A8EF9B-4D21-476A-9C82-7E9A8C4B3F61",
        "{{APP_VERSION}}": version,
        "{{DISPLAY_NAME}}": "Dart + Flutter Demo",
        "{{PUBLISHER_NAME}}": "VincentZyu",
        "{{PUBLISHER_URL}}": "https://github.com/VincentZyuApps/dart-flutter-demo",
        "{{EXECUTABLE_NAME}}": "dart_flutter_demo.exe",
        "{{OUTPUT_BASE_FILENAME}}": "dart-flutter-demo-setup",
        "{{SETUP_ICON_FILE}}": str(icon_file),
        "{{PRIVILEGES_REQUIRED}}": "admin",
        "{{SOURCE_DIR}}": str(build_dir),
    }

    content = template.read_text(encoding="utf-8")
    for key, val in subs.items():
        content = content.replace(key, val)

    out_iss = out_dir / "dart-flutter-demo-setup.iss"
    out_iss.write_text(content, encoding="utf-8")
    print(f"Wrote {out_iss}")


if __name__ == "__main__":
    main()
