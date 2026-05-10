[English](./build.md) | [中文](./build.zh-cn.md)

# Build and Release Workflow

This workflow builds the Flutter app and publishes releases to GitHub Releases.

## Trigger Conditions

The workflow runs under the following conditions:
- Push to `master` or `main` branch
- Pull Request targeting `master` or `main` branch
- Manual trigger via `workflow_dispatch`

## Commit Message Convention

**The full build is only triggered when the commit message contains `build action` or `build release`.**

Otherwise, the workflow will skip the build and display:
```
✗ Commit message does not contain build trigger
   Skipping build (commit: abc1234)
```

### Valid Commit Message Examples (will trigger build)

```bash
git commit -m "feat: build action for Windows and Android"
git commit -m "chore: build release v1.0"
```

### Invalid Commit Messages (will skip build)

```bash
git commit -m "fix: update UI colors"
git commit -m "update readme"
git commit -m "fix typo"
```

## Git Profile Setup

If the GitHub profile shown on the repository homepage or release notes is wrong, run:

```bash
git config --global --replace-all user.name "VincentZyu233"
git config --global user.email "1830540513zyu@gmail.com"
```

## Pipeline Stages

### Stage 1: Check Commit Message

Verify that the commit message contains the required trigger keywords.

- **Runner:** `ubuntu-latest`
- **Output:** `should_build` (boolean)

### Stage 2: Matrix Build

Build artifacts for all three platforms simultaneously using matrix strategy.

- **Runner:** Selected per platform (Windows/Linux/Ubuntu)
- **Dependency:** Flutter stable SDK

**Build Matrix:**

| Platform | Runner | Build Command | Artifact |
|----------|--------|---------------|----------|
| Windows x64 | `windows-latest` | `flutter build windows --release` | `dart-flutter-demo-showcase-windows-x64-v<version>.zip` |
| Linux x64 | `ubuntu-latest` | `flutter build linux --release` | `dart-flutter-demo-showcase-linux-x64-v<version>.tar.gz` |
| Android | `ubuntu-latest` | `flutter build apk --release` | `dart-flutter-demo-showcase-android-v<version>.apk` |

**Execution Steps:**
1. Checkout code
2. Setup Flutter stable SDK
3. Run `flutter doctor -v`
4. Install project dependencies (`flutter pub get`)
5. Static analysis (`flutter analyze`)
6. Generate version tag
7. Execute platform-specific build command
8. Upload build artifacts

**Linux Extra Dependencies:**
```bash
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
```

**Release Tag Format:**
```
v<pubspec-version>
Example: v0.0.1-alpha.1
```

**Artifact Filename Format:**
```
dart-flutter-demo-showcase-<platform>-v<pubspec-version>.<extension>
Example: dart-flutter-demo-showcase-windows-x64-v0.0.1-alpha.1.zip
```

### Stage 3: Publish Release

Create a GitHub Release and upload all build artifacts.

- **Runner:** `ubuntu-latest`
- **Dependency:** All artifacts from the build stage

**Execution Steps:**
1. Checkout code
2. Download all build artifacts
3. Package artifacts with versioned filenames
4. Create Draft Release (draft mode, requires manual publish)
5. Upload Windows/Linux/Android artifacts

**Release Contents:**

| File | Description |
|------|-------------|
| `dart-flutter-demo-showcase-windows-x64-v<version>.zip` | Windows executable archive |
| `dart-flutter-demo-showcase-linux-x64-v<version>.tar.gz` | Linux executable archive |
| `dart-flutter-demo-showcase-android-v<version>.apk` | Android APK package |

## Permissions

- `contents: write` (required for creating Releases)

## Notes

- Uses `softprops/action-gh-release@v2` to create Releases
- Releases are created in **Draft** state by default, requiring manual publish on GitHub
- All artifacts are retained for 7 days (controlled by `retention-days: 7`)
- `fail-fast: false` ensures a single platform build failure does not affect others
- Android build uses `flutter build apk --release` directly
- Version is extracted from `pubspec.yaml` `version` field (part before `+`), used in artifact filenames and Release tag
