# dart_flutter_demo

A cross-platform Flutter UI showcase PoC (Proof of Concept) app for Android, Windows, and Linux.

## Pages

### 0. System Info

Displays system information through native C++ (Windows) and Kotlin (Android) integration, plus dart:io on Linux. Shows OS, hostname, kernel, uptime, CPU, memory, disk, and local IP. Includes a built-in debug trace panel for inspecting collection logs and exportable diagnostics.

### 1. Dialog Lab

A pixel-accurate recreation of a classic Win32 dialog. Uses retro borders, inset input styling, and period-appropriate color treatment to demonstrate that Flutter can reproduce non-native UI conventions without depending on system widgets.

### 2. Typography Studio

An interactive text playground. Adjust font size, letter spacing, and line height with live controls. Switch between the system font and a custom serif font from Google Fonts. Useful for checking text rendering, spacing, and visual rhythm.

### 3. Adaptive Grid

A responsive card grid driven by `LayoutBuilder`. Automatically switches between 1, 2, or 3 columns based on available width. Useful for validating resize behavior on desktop and layout adaptation across device sizes.

### 4. Controls & Feedback

A compact lab for interactive controls and user feedback. Includes radios, checkboxes, switches, progress indicators, snack bars, and bottom sheets. Useful for checking state transitions, motion, and component responsiveness.

## Build & Run

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Release builds
flutter build windows --release
flutter build linux --release
flutter build apk --release
```

## CI/CD

GitHub Actions handles automated builds and packaging. Push a commit containing `build action` or `build release` to trigger the pipeline. See [build.md](.github/workflows/build.md) for details.

## Tech Stack

- Flutter (stable channel)
- Material 3 design system
- Google Fonts plugin
- State management: setState (kept intentionally simple for a PoC)
