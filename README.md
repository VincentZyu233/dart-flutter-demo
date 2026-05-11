![dart-flutter-demo](https://socialify.git.ci/VincentZyuApps/dart-flutter-demo/image?description=1&font=Bitter&forks=1&issues=1&language=1&logo=https%3A%2F%2Fupload.wikimedia.org%2Fwikipedia%2Fcommons%2Fthumb%2F7%2F79%2FFlutter_logo.svg%2F120px-Flutter_logo.svg.png%3Futm_source%3Dcommons.wikimedia.org%26utm_campaign%3Dindex%26utm_content%3Dthumbnail%26_%3D20230821075714&name=1&owner=1&pulls=1&stargazers=1&theme=Auto)

# dart_flutter_demo

A cross-platform Flutter UI showcase PoC (Proof of Concept) app, available on Android, Windows, Linux, macOS, and iOS, build by Github Action CI packaging workflow.

[![Windows x64](https://img.shields.io/badge/Windows-x64-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/VincentZyuApps/dart-flutter-demo/releases)
[![Linux x64 | ARM64](https://img.shields.io/badge/Linux-x64_|_ARM64-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://github.com/VincentZyuApps/dart-flutter-demo/releases)
[![macOS x64 | ARM64](https://img.shields.io/badge/macOS-x64_|_ARM64-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/VincentZyuApps/dart-flutter-demo/releases)

[![Android x86_64 | ARM64](https://img.shields.io/badge/Android-x86_64_|_ARM64-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/VincentZyuApps/dart-flutter-demo/releases)
[![iOS ARM64](https://img.shields.io/badge/iOS-ARM64-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/VincentZyuApps/dart-flutter-demo/releases)

## Dialogs

### About

An app information dialog that displays app name, version, build number, publisher, and related links. Accessible from the AppBar menu.
![about](doc/preview-pics/about.png)

### Getting Started Guide

A step-by-step walkthrough dialog showing the app's download channels, build options, and recommended development setup. Accessible from the AppBar menu.
![guide](doc/preview-pics/guide.png)

## Pages

### 0. System Info

Displays system information through native C++ (Windows), Kotlin (Android), Swift (iOS), and dart:io fallbacks. Shows OS, hostname, kernel, uptime, CPU, memory, disk, and local IP. Includes built-in debug trace viewing plus copy/export actions for diagnostics.
Source: [lib/pages/page0_system_info.dart](https://github.com/VincentZyu233/dart-flutter-demo/blob/main/lib/pages/page0_system_info.dart)
![page0](doc/preview-pics/page0.png)

### 1. Dialog Lab

A compact dialog lab with both a modern Flutter dialog and a classic Win32-style dialog recreation. Uses retro borders, inset input styling, and larger action buttons to demonstrate that Flutter can reproduce very different interaction and visual languages in one app.
Source: [lib/pages/page1_dialog_lab.dart](https://github.com/VincentZyu233/dart-flutter-demo/blob/main/lib/pages/page1_dialog_lab.dart)
![page1](doc/preview-pics/page1.png)

### 2. Typography Studio

An interactive text playground. Adjust font size, letter spacing, and line height with live controls. Switch between the system font, Google Fonts, and a one-shot local font file. Includes live preview text editing, dark/light auto text color switching, preset swatches, and a custom color picker with RGB and HEX readout.
Source: [lib/pages/page2_typography_studio.dart](https://github.com/VincentZyu233/dart-flutter-demo/blob/main/lib/pages/page2_typography_studio.dart)
![page2](doc/preview-pics/page2.png)

### 3. Adaptive Grid

A responsive GitHub repository browser driven by LayoutBuilder. Fetches repositories from configurable personal or organization repository pages, supports proxy configuration, filter and sort controls, collapsible configuration UI, layout switching between Grid / Masonry / List, and adjustable target columns from 5 to 1.
Source: [lib/pages/page3_adaptive_grid.dart](https://github.com/VincentZyu233/dart-flutter-demo/blob/main/lib/pages/page3_adaptive_grid.dart)
![page3](doc/preview-pics/page3.png)

### 4. Controls & Feedback

A compact lab for interactive controls and user feedback. Includes radios, checkboxes, switches, progress indicators, snack bars, and bottom sheets. Useful for checking state transitions, motion, and component responsiveness.
Source: [lib/pages/page4_controls_feedback.dart](https://github.com/VincentZyu233/dart-flutter-demo/blob/main/lib/pages/page4_controls_feedback.dart)
![page4](doc/preview-pics/page4.png)


## CI/CD

GitHub Actions handles automated builds and packaging. Push a commit containing `build action` or `build release` to trigger the pipeline. See [build.md](.github/workflows/build.md) for details.

## Troubleshooting

- **Linux / Windows GPU issues**: Launch with software rendering: `./dart_flutter_demo --disable-gpu`
- **macOS virtual machines graphic issues** (VMware, VirtualBox, etc.): Flutter desktop apps require Apple Metal, which is unavailable in VMs. Use a physical Mac or [GitHub Actions macOS runners](https://github.com/VincentZyuApps/mac-test-action-runner) instead.

## Tech Stack

| Item | Badge |
|------|-------|
| Flutter | ![flutter](https://img.shields.io/badge/Flutter-stable-02569B.svg?logo=flutter) |
| Material 3 | ![material3](https://img.shields.io/badge/Material%203-design%20system-6750A4.svg?logo=materialdesign) |
| Fonts | ![google-fonts](https://img.shields.io/badge/Google%20Fonts-plugin-4285F4.svg?logo=googlefonts) |
| Plugins | ![plugins](https://img.shields.io/badge/file__selector%20%2B%20flutter__colorpicker-plugins-00A884.svg?logo=flutter) |
| App Info | ![package-info-plus](https://img.shields.io/badge/package__info__plus-app%20metadata-FF6F00.svg?logo=dart) |
| Links | ![url-launcher](https://img.shields.io/badge/url__launcher-open%20links-1E88E5.svg?logo=linktree) |
