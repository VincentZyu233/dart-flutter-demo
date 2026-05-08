import 'package:flutter/material.dart';
import '../services/system_info_service.dart';
import '../widgets/animated_page.dart';

class Page0SystemInfo extends StatefulWidget {
  const Page0SystemInfo({super.key});

  @override
  State<Page0SystemInfo> createState() => _Page0SystemInfoState();
}

class _Page0SystemInfoState extends State<Page0SystemInfo> {
  final _service = createSystemInfoService();
  Map<String, String> _info = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await _service.getInfo();
      if (mounted) setState(() { _info = info; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading system info...', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: const Icon(Icons.error_outline, size: 64, color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text('Failed to load system info', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () { setState(() { _loading = true; _error = null; }); _loadInfo(); },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return AnimatedPageWrapper(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TweenAnimationBuilder<int>(
                tween: Tween(begin: 0, end: _asciiArt.length),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOut,
                builder: (context, charCount, child) {
                  return Text(
                    _asciiArt.substring(0, charCount),
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                      height: 1.2,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _info.entries.toList().asMap().entries.map((entry) {
                    return StaggeredItem(
                      index: entry.key,
                      child: _InfoRow(label: entry.value.key, value: entry.value.value),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 16),

            FilledButton.tonalIcon(
              onPressed: () { setState(() { _loading = true; }); _loadInfo(); },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _asciiArt = r'''
         ,--./,-.
        / #      \
       |          |     Flutter Showcase
        \        /      System Information
         `._,._,'       cross-platform demo
''';