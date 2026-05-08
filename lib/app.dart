import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/page0_system_info.dart';
import 'pages/page1_dialog_lab.dart';
import 'pages/page2_typography_studio.dart';
import 'pages/page3_adaptive_grid.dart';
import 'pages/page4_motion_lab.dart';
import 'pages/page5_navigation_hub.dart';
import 'pages/page6_data_feed.dart';
import 'pages/page7_controls_feedback.dart';

class FlutterShowcaseApp extends StatelessWidget {
  const FlutterShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const HomeShell(),
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
    Page4MotionLab(),
    Page6DataFeed(),
    Page7ControlsFeedback(),
  ];

  static const _titles = [
    '0. System Info',
    '1. Dialog Lab',
    '2. Typography',
    '3. Adaptive Grid',
    '4. Motion Lab',
    '5. Data Feed',
    '6. Controls',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.compass_calibration),
            tooltip: 'Navigation Hub (Page 5)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const Page5NavigationHub(),
                ),
              );
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
                showAboutDialog(
                  context: context,
                  applicationName: 'Flutter Showcase',
                  applicationVersion: '1.0.0',
                  children: [
                    const Text(
                      'A PoC app demonstrating Flutter\'s UI capabilities.',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      body: _pages[_currentIndex],
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
            icon: Icon(Icons.animation),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Motion',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            selectedIcon: Icon(Icons.list),
            label: 'Feed',
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
}
