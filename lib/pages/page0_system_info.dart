import 'dart:async';
import 'dart:io' show Platform;

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
  Set<String> _loadingKeys = {};
  SystemInfoDebugSnapshot _debug = getSystemInfoDebugSnapshot();
  bool _loading = false;
  bool _exporting = false;
  bool _copying = false;
  bool _debugExpanded = false;
  String? _error;
  final Stopwatch _loadStopwatch = Stopwatch();
  int? _loadDurationMs;
  int _loadGeneration = 0;
  Timer? _loadTicker;

  List<String> get _keys => [
        'OS',
        'Host',
        'Kernel',
        'Uptime',
        'CPU',
        'Memory',
        if (Platform.isWindows)
          'Disk (C:\\)'
        else if (Platform.isLinux)
          'Disk (/)'
        else
          'Disk',
        'Local IP',
        'Locale',
      ];

  @override
  void initState() {
    super.initState();
    _startLoading();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInfo());
  }

  void _startLoading({Iterable<String>? keys}) {
    _loadTicker?.cancel();
    _loading = true;
    _error = null;
    _loadDurationMs = null;
    _loadingKeys = (keys ?? _keys).toSet();
    _loadStopwatch
      ..reset()
      ..start();
    _loadTicker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || !_loading) return;
      final elapsed = _loadStopwatch.elapsedMilliseconds;
      if (_loadDurationMs == elapsed) return;
      setState(() {
        _loadDurationMs = elapsed;
      });
    });
  }

  Future<void> _loadInfo({bool forceRefresh = false}) async {
    await _refreshFields(forceRefresh: forceRefresh);
  }

  void _refresh() {
    _loadInfo(forceRefresh: true);
  }

  Future<void> _refreshFields({required bool forceRefresh}) async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    try {
      setState(() {
        _startLoading();
      });
      await Future<void>.delayed(Duration.zero);

      final info = await _service.getInfo(
        forceRefresh: forceRefresh,
        onField: (key, value) {
          if (!mounted || generation != _loadGeneration) return;
          setState(() {
            _info[key] = value;
            _loadingKeys.remove(key);
          });
        },
      );
      if (!mounted || generation != _loadGeneration) return;

      if (mounted && generation == _loadGeneration) {
        setState(() {
          _info.addAll(info);
          _loadingKeys.removeAll(info.keys);
          _debug = getSystemInfoDebugSnapshot();
          _loading = false;
          _error = null;
          _loadStopwatch.stop();
          _loadDurationMs = _loadStopwatch.elapsedMilliseconds;
        });
        _loadTicker?.cancel();
        _loadTicker = null;
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _error = e.toString();
          _debug = getSystemInfoDebugSnapshot();
          _loading = false;
          _loadingKeys = <String>{};
          _loadStopwatch.stop();
          _loadDurationMs = _loadStopwatch.elapsedMilliseconds;
        });
        _loadTicker?.cancel();
        _loadTicker = null;
      }
    }
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

  @override
  void dispose() {
    _loadTicker?.cancel();
    super.dispose();
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
                    'Loaded in ${_loadDurationMs ?? 0} ms',
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
                  loading: _loadingKeys.contains(key),
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
    return 'localhost';
  }
}
