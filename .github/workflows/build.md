![flutter-showcase](https://socialify.git.ci/user/flutter-showcase/image?description=1&font=Raleway&forks=1&issues=1&language=1&logo=https%3A%2F%2Ficon.icepanel.io%2FTechnology%2Fsvg%2FGitHub-Actions.svg&name=1&owner=1&pattern=Circuit+Board&pulls=1&stargazers=1&theme=Light)

[English](./build.md) | [中文](./build.zh-cn.md)

# Build and Release Workflow

This workflow builds the Flutter app and publishes releases to GitHub Releases.

## Trigger Conditions

The workflow runs under the following conditions:
- Push to `master` or `main` branch
- Pull Request targeting `master` or `main` branch
- Manual trigger via `workflow_dispatch`

## Commit Message Convention

**The full build is only triggered when the commit message contains `build action` or `build publish`.**

Otherwise, the workflow will skip the build and display:
```
✗ Commit message does not contain build trigger
   Skipping build (commit: abc1234)
```

### Valid Commit Message Examples (will trigger build)

```bash
git commit -m "feat: build action for Windows and Android"
git commit -m "chore: build publish release v1.0"
```

### Invalid Commit Messages (will skip build)

```bash
git commit -m "fix: update UI colors"
git commit -m "update readme"
git commit -m "fix typo"
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
| Windows x64 | `windows-latest` | `flutter build windows --release` | `flutter-showcase-windows-x64.zip` |
| Linux x64 | `ubuntu-latest` | `flutter build linux --release` | `flutter-showcase-linux-x64.tar.gz` |
| Android | `ubuntu-latest` | `flutter build apk --release` | `flutter-showcase-android.apk` |

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

**Version Tag Format:**
```
<first-7-chars-of-commit-hash>-<timestamp>
Example: abc1234-20260508-143000
```

### Stage 3: Publish Release

Create a GitHub Release and upload all build artifacts.

- **Runner:** `ubuntu-latest`
- **Dependency:** All artifacts from the build stage

**Execution Steps:**
1. Checkout code
2. Download all build artifacts
3. Create Draft Release (draft mode, requires manual publish)
4. Upload Windows/Linux/Android artifacts

**Release Contents:**

| File | Description |
|------|-------------|
| `flutter-showcase-windows-x64.zip` | Windows executable archive |
| `flutter-showcase-linux-x64.tar.gz` | Linux executable archive |
| `flutter-showcase-android.apk` | Android APK package |

## Permissions

- `contents: write` (required for creating Releases)

## Notes

- Uses `softprops/action-gh-release@v2` to create Releases
- Releases are created in **Draft** state by default, requiring manual publish on GitHub
- All artifacts are retained for 7 days (controlled by `retention-days: 7`)
- `fail-fast: false` ensures a single platform build failure does not affect others
- Android build uses `sparkfabrik/android-build-action@v1` to handle SDK configuration
