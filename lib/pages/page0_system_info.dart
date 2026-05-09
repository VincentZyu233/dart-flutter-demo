import 'dart:io' show Platform, Process;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  SystemInfoDebugSnapshot _debug = getSystemInfoDebugSnapshot();
  bool _loading = false;
  bool _exporting = false;
  bool _copying = false;
  bool _debugExpanded = false;
  String? _error;
  final Stopwatch _loadStopwatch = Stopwatch();
  int? _loadDurationMs;

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
    _loadStopwatch.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInfo());
  }

  Future<void> _loadInfo({bool forceRefresh = false}) async {
    if (!mounted) return;
    try {
      final info = await _service.getInfo(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _info = info;
          _debug = getSystemInfoDebugSnapshot();
          _loading = false;
          _error = null;
          _loadStopwatch.stop();
          _loadDurationMs = _loadStopwatch.elapsedMilliseconds;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _debug = getSystemInfoDebugSnapshot();
          _loading = false;
          _loadStopwatch.stop();
          _loadDurationMs = _loadStopwatch.elapsedMilliseconds;
        });
      }
    }
  }

  void _refresh() {
    setState(() {
      _loading = true;
      _error = null;
      _loadDurationMs = null;
      _loadStopwatch
        ..reset()
        ..start();
    });
    _loadInfo(forceRefresh: true);
  }

  Future<void> _exportLogs() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
    });

    try {
      final file = await exportSystemInfoDebugSnapshot();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Log exported: ${file.path}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _copyLogs() async {
    if (_copying) return;
    setState(() {
      _copying = true;
    });

    try {
      final copiedChars = await copySystemInfoDebugSnapshotToClipboard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Log copied to clipboard: $copiedChars chars'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copy failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _copying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedPageWrapper(
      child: SelectionArea(
        child: Scrollbar(
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 80,
            ),
            children: [
              _buildHeader(theme),
              const SizedBox(height: 2),
              _buildSeparator(theme),
              const SizedBox(height: 8),
              if (_loadDurationMs != null && !_loading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Loaded in $_loadDurationMs ms',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ),
              if (_error != null && !_loading) _buildErrorBanner(theme),
              for (final key in _keys)
                _InfoRow(
                  label: key,
                  value: _info[key],
                  loading: _loading && !_info.containsKey(key),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
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
                  OutlinedButton.icon(
                    onPressed: _exporting ? null : _exportLogs,
                    icon: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(_exporting ? 'Exporting...' : 'Export Log'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _copying ? null : _copyLogs,
                    icon: _copying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.content_copy_rounded),
                    label: Text(_copying ? 'Copying...' : 'Copy Log'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDebugPanel(theme),
            ],
          ),
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
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'JetBrainsMono',
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugPanel(ThemeData theme) {
    final logs = _debug.logs;
    final fields = _debug.data.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('\n');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        initiallyExpanded: _debugExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _debugExpanded = expanded;
          });
        },
        title: Text(
          'Debug Trace',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        subtitle: Text(
          'source=${_debug.source}  logs=${logs.length}',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10.5,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        children: [
          _DebugKv(label: 'platform', value: _debug.platform),
          _DebugKv(label: 'source', value: _debug.source),
          _DebugKv(label: 'fields', value: fields),
          SelectableText(
            logs.isEmpty ? 'No debug logs captured yet.' : logs.join('\n'),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
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

  Future<void> _copyRow(BuildContext context) async {
    final text = '$label\n${value ?? '-'}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $label'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: loading ? null : () => _copyRow(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 115.5,
              child: SelectableText(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.bold,
                  fontSize: 14.4,
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
                            fontSize: 15.6,
                            color: theme.colorScheme.onSurface.withOpacity(0.55),
                          ),
                        ),
                      ],
                    )
                  : SelectableText(
                      value ?? '-',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 15.6,
                        color: theme.colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugKv extends StatelessWidget {
  final String label;
  final String value;

  const _DebugKv({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value.isEmpty ? '-' : value,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              height: 1.35,
              color: theme.colorScheme.onSurface.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

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
