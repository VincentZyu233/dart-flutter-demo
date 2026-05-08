import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Page5NavigationHub extends StatelessWidget {
  const Page5NavigationHub({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Navigation Hub'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Components', icon: Icon(Icons.widgets)),
              Tab(text: 'Layout', icon: Icon(Icons.dashboard)),
              Tab(text: 'Settings', icon: Icon(Icons.settings)),
            ],
          ),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const UserAccountsDrawerHeader(
                accountName: Text('Demo User'),
                accountEmail: Text('demo@flutter.dev'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 36),
                ),
                otherAccountsPictures: [
                  CircleAvatar(child: Icon(Icons.add)),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Favorites'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About'),
                onTap: () {
                  Navigator.pop(context);
                  showAboutDialog(
                    context: context,
                    applicationName: 'Navigation Hub',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.explore, size: 48),
                    children: [
                      const Text('Navigation Hub – part of Flutter Showcase'),
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
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ComponentsTab(),
            _LayoutTab(),
            _SettingsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('FAB pressed – Hero animation demo ready'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _ComponentsTab extends StatelessWidget {
  const _ComponentsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section('Hero Animation', const _HeroDemo()),
        const SizedBox(height: 16),
        _section('Page Transition', const _PageTransitionDemo()),
      ],
    );
  }
}

class _HeroDemo extends StatelessWidget {
  const _HeroDemo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final colors = [Colors.blue, Colors.red, Colors.green];
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 600),
                  pageBuilder: (_, a1, a2) => _HeroDetailPage(
                    tag: 'hero$i',
                    color: colors[i],
                    label: 'Item ${i + 1}',
                  ),
                  transitionsBuilder: (_, a1, a2, child) {
                    return FadeTransition(opacity: a1, child: child);
                  },
                ),
              );
            },
            child: Hero(
              tag: 'hero$i',
              child: Material(
                color: colors[i],
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _HeroDetailPage extends StatelessWidget {
  final String tag;
  final Color color;
  final String label;

  const _HeroDetailPage({
    required this.tag,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Hero(
          tag: tag,
          child: Material(
            color: color,
            child: Container(
              width: double.infinity,
              height: 200,
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageTransitionDemo extends StatelessWidget {
  const _PageTransitionDemo();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _transitionChip(context, 'FadeThrough', _FadeThroughPage()),
        _transitionChip(context, 'Scale', _ScalePage()),
        _transitionChip(context, 'Slide', _SlidePage()),
      ],
    );
  }

  Widget _transitionChip(BuildContext context, String label, Widget page) {
    return ActionChip(
      label: Text(label),
      onPressed: () => Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, a1, a2) => page,
          transitionsBuilder: (_, a1, a2, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: a1, curve: Curves.easeInOut),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _FadeThroughPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      _transitionPage(context, 'Fade Through Transition');
}

class _ScalePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      _transitionPage(context, 'Scale Transition');
}

class _SlidePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      _transitionPage(context, 'Slide Transition');
}

Widget _transitionPage(BuildContext context, String title) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    ),
  );
}

class _LayoutTab extends StatelessWidget {
  const _LayoutTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section('Stack (Overlay)', SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white),
              ),
            ],
          ),
        )),
        const SizedBox(height: 16),
        _section('Wrap', Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            12,
            (i) => Chip(label: Text('Tag ${i + 1}')),
          ),
        )),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SwitchListTile(
          title: Text('Dark Mode'),
          subtitle: Text('Toggle between light and dark theme'),
          value: false,
          onChanged: null,
        ),
        SwitchListTile(
          title: Text('Notifications'),
          subtitle: Text('Enable push notifications'),
          value: true,
          onChanged: null,
        ),
        ListTile(
          title: Text('Language'),
          subtitle: Text('English'),
          trailing: Icon(Icons.chevron_right),
        ),
        ListTile(
          title: Text('Version'),
          subtitle: Text('1.0.0'),
        ),
      ],
    );
  }
}

Widget _section(String title, Widget child) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}
