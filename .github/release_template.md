<div align=center>

[![Downloads](https://img.shields.io/github/downloads/__REPO__/v__VERSION__/total?style=flat-square&logo=github)](https://github.com/__REPO__/releases/tag/v__VERSION__)

</div>


### ⬇️ Downloads

| OS / Arch | x86_64 | ARM64 | Universal |
|-----------|--------|-------|-----------|
| **Windows** | [![windows-x64-setup](https://img.shields.io/badge/windows-x64_setup-0078D4.svg?logo=windows)](__BASE_URL__/dart-flutter-demo-windows-x64-v__VERSION__-setup.exe) · [![windows-x64-zip](https://img.shields.io/badge/windows-x64_zip-67b7d1.svg?logo=windows)](__BASE_URL__/dart-flutter-demo-windows-x64-v__VERSION__.zip) | *none yet* | *none yet* |
| **Linux** | [![linux-x64-appimage](https://img.shields.io/badge/linux-x64_AppImage-f84e29.svg?logo=linux)](__BASE_URL__/dart-flutter-demo-linux-x64-v__VERSION__.AppImage) · [![linux-x64-deb](https://img.shields.io/badge/linux-x64_deb-CE0056.svg?logo=debian)](__BASE_URL__/dart-flutter-demo-linux-x64-v__VERSION__.deb) · [![linux-x64-tar](https://img.shields.io/badge/linux-x64_tar.gz-E95420.svg?logo=linux)](__BASE_URL__/dart-flutter-demo-linux-x64-v__VERSION__.tar.gz) | *none yet* | *none yet* |
| **macOS** | [![macos-x64](https://img.shields.io/badge/macOS-x64_dmg-8E8E93.svg?logo=apple)](__BASE_URL__/dart-flutter-demo-macos-x64-v__VERSION__.dmg) | [![macos-arm64](https://img.shields.io/badge/macOS-ARM64_dmg-8E8E93.svg?logo=apple)](__BASE_URL__/dart-flutter-demo-macos-arm64-v__VERSION__.dmg) | *none yet* |
| **Android** | [![android-x64](https://img.shields.io/badge/android-x64_apk-8FE388.svg?logo=android)](__BASE_URL__/dart-flutter-demo-android-x86_64-v__VERSION__.apk) | [![android-arm64](https://img.shields.io/badge/android-ARM64_apk-168039.svg?logo=android)](__BASE_URL__/dart-flutter-demo-android-arm64-v__VERSION__.apk) | [![android-universal](https://img.shields.io/badge/android-universal_apk-3DDC84.svg?logo=android)](__BASE_URL__/dart-flutter-demo-android-universal-v__VERSION__.apk) |
| **iOS** | *none yet* | [![ios-arm64](https://img.shields.io/badge/iOS-ARM64_ipa-000000.svg?logo=apple)](__BASE_URL__/dart-flutter-demo-ios-arm64-v__VERSION__.ipa) | *none yet* |

> *`none yet`* means this platform is not included in the current GitHub Actions build matrix yet.
>
> ⚠️ **Linux / Windows GPU issues**: If the app fails to render correctly, launch it with software rendering: `./dart_flutter_demo --disable-gpu`
>
> ⚠️ **macOS virtual machines**: Flutter desktop apps require Apple Metal, which is unavailable in VMware, VirtualBox, and similar VMs. Use a physical Mac or [GitHub Actions macOS runners](https://github.com/VincentZyuApps/mac-test-action-runner) instead.
>
> ⚠️ **Android**: APKs are not signed with a persistent keystore, so you must uninstall the previous version before installing a new one to avoid signature conflicts.
>
> ⚠️ **iOS**: The IPA is not code-signed for personal devices. To install it on your own iPhone or iPad, self-sign it first. For example, on Windows you can use AltStore / AltServer: install AltServer, connect the device by USB, install AltStore to the device, trust your Apple ID certificate under **Settings → General → VPN & Device Management**, then open AltStore and import the `.ipa`. Free Apple IDs require re-signing every 7 days.

### 📥 Quick Install

__BUILD_INFO__

### Commit Log

__COMMIT_LOG__
