import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/system_info_service.dart';

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
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Failed to load system info', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ASCII art header (fastfetch style)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _asciiArt,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: theme.colorScheme.primary,
                height: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // System info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _info.entries.map((e) => _InfoRow(
                  label: e.key,
                  value: e.value,
                )).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Refresh button
          FilledButton.tonalIcon(
            onPressed: () { setState(() { _loading = true; }); _loadInfo(); },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
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
