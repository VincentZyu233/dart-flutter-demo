import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pages/page0_system_info.dart';
import 'pages/page1_dialog_lab.dart';
import 'pages/page2_typography_studio.dart';
import 'pages/page3_adaptive_grid.dart';
import 'pages/page4_controls_feedback.dart';
import 'services/app_performance.dart';
import 'widgets/animated_page.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void toggleThemeMode() {
  themeNotifier.value = switch (themeNotifier.value) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  };
}

class FlutterShowcaseApp extends StatelessWidget {
  const FlutterShowcaseApp({super.key});

  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    },
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Dart + Flutter Demo',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            useMaterial3: true,
            brightness: Brightness.light,
            textTheme: GoogleFonts.interTextTheme(),
            pageTransitionsTheme: _pageTransitions,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            useMaterial3: true,
            brightness: Brightness.dark,
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            pageTransitionsTheme: _pageTransitions,
          ),
          home: const HomeShell(),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  Future<PackageInfo>? _packageInfoFuture;
  final FrameFpsTracker _fpsTracker = FrameFpsTracker();
  int _shellBuildCount = 0;

  static const _pages = [
    Page0SystemInfo(),
    Page1DialogLab(),
    Page2TypographyStudio(),
    Page3AdaptiveGrid(),
    Page4ControlsFeedback(),
  ];

  static const _titles = [
    '0. System Info',
    '1. Dialog Lab',
    '2. Typography',
    '3. Adaptive Grid',
    '4. Controls',
  ];

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
    WidgetsBinding.instance.addTimingsCallback(_fpsTracker.addTimings);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_fpsTracker.addTimings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= _pages.length) {
      _currentIndex = _pages.length - 1;
    }
    _shellBuildCount++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      shellRebuildCountNotifier.value = _shellBuildCount;
    });
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        final themeIcon = switch (themeMode) {
          ThemeMode.system => Icons.desktop_windows_outlined,
          ThemeMode.light => Icons.wb_sunny_outlined,
          ThemeMode.dark => Icons.nightlight_round,
        };
        final themeTooltip = switch (themeMode) {
          ThemeMode.system => 'Theme: follow system',
          ThemeMode.light => 'Theme: light mode',
          ThemeMode.dark => 'Theme: dark mode',
        };
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_titles[_currentIndex]),
                const SizedBox(width: 10),
                _PerfChip(fpsTracker: _fpsTracker),
              ],
            ),
            actions: [
              IconButton(
                tooltip: '$themeTooltip. Tap to switch.',
                icon: Icon(themeIcon),
                onPressed: toggleThemeMode,
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                FutureBuilder<PackageInfo>(
                  future: _packageInfoFuture,
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    final appName = (info?.appName.isNotEmpty ?? false)
                        ? info!.appName
                        : 'dart_flutter_demo';
                    final version = info == null
                        ? 'version loading...'
                        : '${info.version}+${info.buildNumber}';
                    return UserAccountsDrawerHeader(
                      accountName: Text(appName),
                      accountEmail: Text(version),
                      currentAccountPicture: const CircleAvatar(
                        backgroundImage: AssetImage(
                          'assets/images/mahiro-pfp-VincentZyu-square.png',
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: const Text('Source Code On Github'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutDialog(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Guide'),
                  subtitle: const Text('What the 5 pages do'),
                  onTap: () {
                    Navigator.pop(context);
                    _showGuideDialog(context);
                  },
                ),
              ],
            ),
          ),
          body: PageSwitcher(
            key_: _currentIndex,
            child: _pages[_currentIndex],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.info_outline),
                selectedIcon: Icon(Icons.info),
                label: 'System',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Dialog',
              ),
              NavigationDestination(
                icon: Icon(Icons.text_fields),
                selectedIcon: Icon(Icons.text_snippet),
                label: 'Type',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view),
                selectedIcon: Icon(Icons.grid_on),
                label: 'Grid',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune),
                selectedIcon: Icon(Icons.settings_input_component),
                label: 'Controls',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'Dart + Flutter Demo',
      applicationVersion: '${info.version}+${info.buildNumber}',
      applicationIcon: const CircleAvatar(
        radius: 24,
        backgroundImage: AssetImage('assets/images/mahiro-pfp-VincentZyu-square.png'),
      ),
      children: [
        const Text(
          'A proof-of-concept app for testing Flutter UI, motion, layout, and cross-platform consistency.',
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => launchUrl(Uri.parse('https://github.com/VincentZyu233/dart-flutter-demo')),
          child: Text(
            'https://github.com/VincentZyu233/dart-flutter-demo',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showGuideDialog(BuildContext context) async {
    const repoUrl = 'https://github.com/VincentZyu233/dart-flutter-demo';
    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Page Guide'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGuideEntry(
                  dialogContext: context,
                  index: 0,
                  title: '0. System Info',
                  description: 'Native and fallback system information with debug trace and export tools.',
                ),
                const SizedBox(height: 8),
                _buildGuideEntry(
                  dialogContext: context,
                  index: 1,
                  title: '1. Dialog Lab',
                  description: 'Modern Flutter dialog and classic Win32-style dialog comparison.',
                ),
                const SizedBox(height: 8),
                _buildGuideEntry(
                  dialogContext: context,
                  index: 2,
                  title: '2. Typography Studio',
                  description: 'Font, spacing, color, local font file, and live text preview testing.',
                ),
                const SizedBox(height: 8),
                _buildGuideEntry(
                  dialogContext: context,
                  index: 3,
                  title: '3. Adaptive Grid',
                  description: 'GitHub repository fetching, filter/sort, and Grid / Masonry / List layout experiments.',
                ),
                const SizedBox(height: 8),
                _buildGuideEntry(
                  dialogContext: context,
                  index: 4,
                  title: '4. Controls & Feedback',
                  description: 'Switches, radios, checkboxes, progress, snack bars, and bottom sheets.',
                ),
                const SizedBox(height: 12),
                const Text('Want more detailed notes? See the README here:'),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => launchUrl(Uri.parse(repoUrl)),
                  child: Text(
                    repoUrl,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideEntry({
    required BuildContext dialogContext,
    required int index,
    required String title,
    required String description,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.pop(dialogContext);
        setState(() => _currentIndex = index);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.arrow_right_rounded),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerfChip extends StatelessWidget {
  final FrameFpsTracker fpsTracker;

  const _PerfChip({required this.fpsTracker});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        shellRebuildCountNotifier,
      ]),
      builder: (context, _) {
        final fps = fpsTracker.fps;
        final rebuilds = shellRebuildCountNotifier.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Text(
            'FPS ${fps.toStringAsFixed(0)}  •  Rebuild $rebuilds',
            style: TextStyle(
              fontSize: 10.5,
              fontFamily: 'JetBrainsMono',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
