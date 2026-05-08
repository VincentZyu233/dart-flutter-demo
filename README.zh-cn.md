# Flutter Showcase

一个跨平台 Flutter UI 能力展示 PoC 应用，支持 Android、Windows 和 Linux。

## 页面介绍

### 0. 系统信息实验室

通过 C++ (Windows) 和 Kotlin (Android) 原生插件及 dart:io (Linux) 获取系统信息。展示 OS、主机名、内核、运行时间、CPU、内存、磁盘和本地 IP。证明 Flutter 无缝桥接原生代码的能力。

### 1. 经典对话框实验室

像素级还原经典 Win32 对话框。3D 凸起边框、内阴影输入框、蓝底白字标题栏。证明 Flutter 不依赖原生系统组件，可以 100% 还原任何时代的 UI 规范。

### 2. 文字排版工作室

交互式文字排版实验场。拖动滑块实时调节字号、字间距、行高。一键切换系统字体与 Google Fonts 自定义衬线字体。点击色块更换文字颜色。展示 Flutter 文本渲染引擎的平滑度。

### 3. 响应式布局挑战

瀑布流风格的自适应卡片网格。使用 `LayoutBuilder` 监听屏幕宽度，自动在 1 列 / 2 列 / 3 列之间切换。拖拽窗口边缘即可看到布局即时重排。

### 4. 动效与交互实验室

模拟注册表单。所有元素带依次错开的 FadeIn + Slide 入场动画。输入 "admin" 时错误提示变红跳动。提交按钮触发从左到右的进度条动画。展示高频动画下的流畅渲染表现。

### 5. 导航与层级实验室

三种导航模式共存：顶部 TabBar 标签页、侧边 Drawer 抽屉、底部 NavigationBar。Hero 动画让元素在页面间飞越。还展示了 Stack 层叠布局和 Wrap 流式布局。

### 6. 数据流与列表展示

长列表下拉刷新 + 无限滚动。每张卡片包含随机头像、姓名和占位文案。右上角按钮一键切换列表/网格视图。证明即使几千条数据，Flutter 列表也不会卡顿。

### 7. 控件与反馈实验室

Radio 单选、Checkbox 多选、Switch 开关。点击 "Start Process" 观察线性进度条 + 旋转加载圈的联合动画。弹出 SnackBar 轻提示和 BottomSheet 底部面板。所有控件状态实时联动反馈。

## 构建与运行

```bash
# 安装依赖
flutter pub get

# 调试模式运行
flutter run

# Release 构建
flutter build windows --release
flutter build linux --release
flutter build apk --release
```

## CI/CD

GitHub Actions 工作流自动构建发布。提交信息包含 `build action` 或 `build release` 即触发流水线。详见 [build.zh-cn.md](.github/workflows/build.zh-cn.md)。

## 技术栈

- Flutter (stable 通道)
- Material 3 设计系统
- Google Fonts 插件
- 状态管理: setState（PoC 保持简单）