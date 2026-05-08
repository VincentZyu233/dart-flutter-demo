import 'dart:io' show Platform, Process;
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
  bool _loading = false;
  String? _error;

  static const List<String> _keys = [
    'OS',
    'Host',
    'Kernel',
    'Uptime',
    'CPU',
    'Memory',
    'Disk (C:\\)',
    'Local IP',
    'Locale',
  ];

  @override
  void initState() {
    super.initState();
    _loading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInfo());
  }

  Future<void> _loadInfo({bool forceRefresh = false}) async {
    if (!mounted) return;
    try {
      final info = await _service.getInfo(forceRefresh: forceRefresh);
      if (mounted) setState(() { _info = info; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _refresh() {
    setState(() { _loading = true; _error = null; });
    _loadInfo(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedPageWrapper(
      child: Scrollbar(
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
          children: [
            _buildHeader(theme),
            const SizedBox(height: 2),
            _buildSeparator(theme),
            const SizedBox(height: 8),
            if (_error != null && !_loading) _buildErrorBanner(theme),
            for (final key in _keys)
              _InfoRow(
                label: key,
                value: _info[key],
                loading: _loading && !_info.containsKey(key),
              ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _loading ? null : _refresh,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_loading ? 'Loading...' : 'Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.terminal, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            PlatformInfo.hostname,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const Spacer(),
          Text(
            'fastfetch style',
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeparator(ThemeData theme) {
    return Container(
      height: 1,
      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
    );
  }

  Widget _buildErrorBanner(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_error!, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontFamily: 'JetBrainsMono', color: theme.colorScheme.onErrorContainer)),
            ),
          ],
        ),
      ),
    );
  }

}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool loading;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: loading
                ? Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                    ],
                  )
                : Text(
                    value ?? '-',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Minimal cross-platform hostname helper.
abstract class PlatformInfo {
  static String get hostname {
    if (_cachedHostname != null) return _cachedHostname!;
    try {
      _cachedHostname = Platform.localHostname;
    } catch (_) {
      _cachedHostname = _hostnameViaProcess();
    }
    return _cachedHostname!;
  }

  static String? _cachedHostname;

  static String _hostnameViaProcess() {
    try {
      final result = Process.runSync('hostname', [], runInShell: true);
      if (result.exitCode == 0) return result.stdout.toString().trim();
    } catch (_) {}
    return 'localhost';
  }
}
