import os
import shutil
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GENERATED_ICONS = os.path.join(REPO_ROOT, "assets", "generated-icons")


def _copy_all(src_dir, dst_dir):
    os.makedirs(dst_dir, exist_ok=True)
    for name in os.listdir(src_dir):
        shutil.copy2(os.path.join(src_dir, name), os.path.join(dst_dir, name))


def apply_windows():
    src = os.path.join(GENERATED_ICONS, "windows", "app_icon.ico")
    dst = os.path.join(REPO_ROOT, "windows", "runner", "resources", "app_icon.ico")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)


def apply_macos():
    src = os.path.join(GENERATED_ICONS, "macos", "AppIcon.appiconset")
    dst = os.path.join(
        REPO_ROOT, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset"
    )
    _copy_all(src, dst)


def apply_linux():
    pass


def apply_android():
    for density in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
        src = os.path.join(
            GENERATED_ICONS, "android", f"mipmap-{density}", "ic_launcher.png"
        )
        dst_dir = os.path.join(
            REPO_ROOT, "android", "app", "src", "main", "res", f"mipmap-{density}"
        )
        os.makedirs(dst_dir, exist_ok=True)
        for name in (
            "ic_launcher.png",
            "ic_launcher_round.png",
            "ic_launcher_foreground.png",
        ):
            shutil.copy2(src, os.path.join(dst_dir, name))

    values_dir = os.path.join(
        REPO_ROOT, "android", "app", "src", "main", "res", "values"
    )
    os.makedirs(values_dir, exist_ok=True)
    with open(os.path.join(values_dir, "ic_launcher_background.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n')
        f.write("<resources>\n")
        f.write('    <color name="ic_launcher_background">#FFFFFF</color>\n')
        f.write("</resources>\n")

    anydpi_dir = os.path.join(
        REPO_ROOT, "android", "app", "src", "main", "res", "mipmap-anydpi-v26"
    )
    os.makedirs(anydpi_dir, exist_ok=True)
    adaptive = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n"
    )
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(anydpi_dir, name), "w") as f:
            f.write(adaptive)


def apply_ios():
    src = os.path.join(GENERATED_ICONS, "ios", "AppIcon.appiconset")
    dst = os.path.join(
        REPO_ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
    )
    _copy_all(src, dst)


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <platform>", file=sys.stderr)
        sys.exit(1)

    platform = sys.argv[1]
    handlers = {
        "windows-x64": apply_windows,
        "macos-x64": apply_macos,
        "macos-arm64": apply_macos,
        "linux-x64": apply_linux,
        "android-multiarch": apply_android,
        "ios-arm64": apply_ios,
    }

    handler = handlers.get(platform)
    if handler is None:
        print(f"Unknown platform: {platform}", file=sys.stderr)
        sys.exit(1)

    print(f"Applying icons for {platform}...")
    handler()
    print(f"Applied generated app icons for {platform}")


if __name__ == "__main__":
    main()
