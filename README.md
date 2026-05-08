# Flutter Showcase

A multi-platform PoC app demonstrating Flutter's UI capabilities across Android, Windows, and Linux.

## Pages

### 1. Dialog Lab

A pixel-perfect recreation of a classic Win32 dialog box. Demonstrates Flutter's ability to reproduce any UI style — retro 3D borders, inset shadows, and era-accurate color schemes. Proves that Flutter doesn't depend on native system components.

### 2. Typography Studio

Interactive text playground. Adjust font size, letter spacing, line height with real-time sliders. Toggle between system font and a custom serif font (Google Fonts). Pick text colors. Shows off Flutter's smooth text rendering engine.

### 3. Adaptive Grid

A responsive masonry-style card grid. Uses `LayoutBuilder` to monitor screen width. Automatically switches between 1, 2, or 3 columns based on device. Drag to resize the window and watch the layout adapt instantly.

### 4. Motion Lab

A simulated registration form with staggered fade-in/slide entrance animations. Real-time input validation — type "admin" and watch the error message bounce. Submit button triggers a linear progress animation. Shows 60/120 FPS rendering with simple state management.

### 5. Navigation Hub

Demonstrates three navigation patterns working together: `TabBar`, `Drawer`, and `BottomNavigationBar`. Features Hero animations that let elements fly between pages. Includes a Stack overlay demo and a Wrap layout demo.

### 6. Data Feed

A long scrolling list with pull-to-refresh and infinite scroll. Each card contains a random avatar, name, and placeholder text. Toggle between list view and grid view with the toolbar button. Proves Flutter handles thousands of items without jank.

### 7. Controls & Feedback

All the interactive controls you need in one place: Radio buttons, Checkboxes, Switches. Press "Start Process" to watch a combined linear + circular progress animation. Trigger SnackBars and BottomSheets for feedback patterns.

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

GitHub Actions workflow handles automated builds. Push a commit containing `build action` or `build publish` to trigger the pipeline. See [build.zh-cn.md](.github/workflows/build.zh-cn.md) for details.

## Tech Stack

- Flutter (stable channel)
- Material 3 design system
- Google Fonts plugin
- State management: setState (keep it simple for a PoC)