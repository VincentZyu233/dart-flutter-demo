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

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

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
  Widget build(BuildContext context) {
    if (_currentIndex >= _pages.length) {
      _currentIndex = _pages.length - 1;
    }
    final isDark = themeNotifier.value == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text('Flutter Showcase'),
              accountEmail: Text('PoC v1.0'),
              currentAccountPicture: CircleAvatar(
                child: Icon(Icons.flutter_dash),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
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
