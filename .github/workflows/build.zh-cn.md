![dart-flutter-demo-showcase](https://socialify.git.ci/user/dart-flutter-demo-showcase/image?description=1&font=Raleway&forks=1&issues=1&language=1&logo=https%3A%2F%2Ficon.icepanel.io%2FTechnology%2Fsvg%2FGitHub-Actions.svg&name=1&owner=1&pattern=Circuit+Board&pulls=1&stargazers=1&theme=Light)

[English](./build.md) | [中文](./build.zh-cn.md)

# Build and Release 工作流

此工作流用于构建 Flutter 应用并发布到 GitHub Releases。

## 触发条件

工作流在以下情况运行：
- 推送到 `master` 或 `main` 分支
- 向 `master` 或 `main` 分支发起 Pull Request
- 通过 `workflow_dispatch` 手动触发

## Commit 信息规范

**只有 commit 信息包含 `build action` 或 `build release` 时才会触发完整构建。**

否则工作流将跳过构建并显示：
```
✗ Commit message does not contain build trigger
   Skipping build (commit: abc1234)
```

### 合法的 Commit 信息示例（将触发构建）

```bash
git commit -m "feat: build action for Windows and Android"
git commit -m "chore: build release v1.0"
```

### 非法的 Commit 信息（将跳过构建）

```bash
git commit -m "fix: update UI colors"
git commit -m "update readme"
git commit -m "fix typo"
```

## 流水线阶段

### 阶段一：检查 Commit 信息

验证 commit 信息是否包含必需的触发关键词。

- **运行环境：** `ubuntu-latest`
- **输出：** `should_build` (布尔值)

### 阶段二：Matrix 构建

使用 matrix strategy 同时构建三个平台的产物。

- **运行环境：** 根据平台选择（Windows/Linux/Ubuntu）
- **依赖：** Flutter stable SDK

**构建矩阵：**

| 平台 | Runner | 构建命令 | 产物 |
|------|--------|----------|------|
| Windows x64 | `windows-latest` | `flutter build windows --release` | `dart-flutter-demo-showcase-windows-x64-v<version>.zip` |
| Linux x64 | `ubuntu-latest` | `flutter build linux --release` | `dart-flutter-demo-showcase-linux-x64-v<version>.tar.gz` |
| Android | `ubuntu-latest` | `flutter build apk --release` | `dart-flutter-demo-showcase-android-v<version>.apk` |

**执行步骤：**
1. 检出代码
2. 配置 Flutter stable SDK
3. 运行 `flutter doctor -v`
4. 安装项目依赖 (`flutter pub get`)
5. 代码静态分析 (`flutter analyze`)
6. 生成版本标签
7. 根据平台执行对应的构建命令
8. 上传构建产物

**Linux 额外依赖：**
```bash
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
```

**Release Tag 格式：**
```
v<pubspec版本号>
示例：v0.0.1-alpha.1
```

**产物文件名格式：**
```
dart-flutter-demo-showcase-<平台>-v<pubspec版本号>.<扩展名>
示例：dart-flutter-demo-showcase-windows-x64-v0.0.1-alpha.1.zip
```

### 阶段三：发布 Release

创建 GitHub Release 并上传所有构建产物。

- **运行环境：** `ubuntu-latest`
- **依赖：** build 阶段的所有产物

**执行步骤：**
1. 检出代码
2. 下载所有构建产物
3. 打包产物并添加版本号文件名
4. 创建 Draft Release（草稿模式，需手动发布）
5. 上传 Windows/Linux/Android 产物

**Release 内容：**

| 文件 | 说明 |
|------|------|
| `dart-flutter-demo-showcase-windows-x64-v<version>.zip` | Windows 可执行文件压缩包 |
| `dart-flutter-demo-showcase-linux-x64-v<version>.tar.gz` | Linux 可执行文件压缩包 |
| `dart-flutter-demo-showcase-android-v<version>.apk` | Android 安装包 |

## 权限

- `contents: write`（创建 Release 需要写权限）

## 注意事项

- 使用 `softprops/action-gh-release@v2` 创建 Release
- Release 默认为 **Draft**（草稿）状态，需手动在 GitHub 上点击 Publish
- 所有产物保留 7 天（通过 `retention-days: 7` 控制）
- `fail-fast: false` 确保单个平台构建失败不会影响其他平台
- Android 构建直接使用 `flutter build apk --release`
- 版本号从 `pubspec.yaml` 的 `version` 字段读取（取 `+` 前部分），用于产物文件名和 Release tag
