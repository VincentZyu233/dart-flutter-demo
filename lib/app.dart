import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pages/page0_system_info.dart';
import 'pages/page1_dialog_lab.dart';
import 'pages/page2_typography_studio.dart';
import 'pages/page3_adaptive_grid.dart';
import 'pages/page4_controls_feedback.dart';
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
          title: 'Flutter Showcase',
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
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= _pages.length) {
      _currentIndex = _pages.length - 1;
    }
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
            title: Text(_titles[_currentIndex]),
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
                        child: Icon(Icons.flutter_dash),
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
      applicationName: 'Flutter Showcase',
      applicationVersion: '${info.version}+${info.buildNumber}',
      applicationIcon: const Icon(Icons.flutter_dash, size: 48),
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
}
