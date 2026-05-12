import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/page3_enums.dart';
import '../services/github_repository_service.dart';
import '../widgets/animated_page.dart';
import '../widgets/repository_card.dart';
import '../widgets/repository_list_tile.dart';
import '../widgets/state_shell.dart';

class Page3AdaptiveGrid extends StatefulWidget {
  const Page3AdaptiveGrid({super.key});

  @override
  State<Page3AdaptiveGrid> createState() => _Page3AdaptiveGridState();
}

class _Page3AdaptiveGridState extends State<Page3AdaptiveGrid> {
  static const _defaultSources = <String>[
    'https://github.com/VincentZyu233?tab=repositories',
    'https://github.com/orgs/VincentZyuApps/repositories',
  ];

  final _service = GitHubRepositoryService();
  final _searchController = TextEditingController();
  final _proxyController = TextEditingController(text: 'http://127.0.0.1:7890');
  final List<TextEditingController> _sourceControllers = [];

  LayoutMode _layoutMode = LayoutMode.masonry;
  DensityMode _densityMode = DensityMode.three;
  SortMode _sortMode = SortMode.updated;
  bool _useProxy = false;
  bool _controlsExpanded = false;
  bool _autoColumns = true;
  bool _animateTransitions = true;

  bool _loading = false;
  String? _error;
  String _status = 'Ready';
  List<GitHubRepositoryItem> _repositories = const [];
  List<String> _logs = const [];

  @override
  void initState() {
    super.initState();
    for (final source in _defaultSources) {
      _sourceControllers.add(TextEditingController(text: source));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _proxyController.dispose();
    for (final controller in _sourceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    final sources = _sourceControllers.map((c) => c.text.trim()).where((v) => v.isNotEmpty).toList();
    if (sources.isEmpty) {
      setState(() {
        _error = 'Add at least one GitHub repositories page.';
        _status = 'No sources';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _status = 'Loading...';
    });

    try {
      final result = await _service.fetchRepositories(
        sourceUrls: sources,
        useProxy: _useProxy,
        proxyUrl: _proxyController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _repositories = _sortRepositories(result.repositories);
        _logs = result.logs;
        _status = 'Loaded ${_repositories.length} repositories from ${sources.length} sources';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = 'Load failed';
        _logs = ['Error: $e'];
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<GitHubRepositoryItem> get _filteredRepositories {
    final query = _searchController.text.trim().toLowerCase();
    final sorted = _sortRepositories(_repositories);
    if (query.isEmpty) return sorted;
    return sorted.where((repo) {
      return repo.name.toLowerCase().contains(query) ||
          repo.fullName.toLowerCase().contains(query) ||
          (repo.description ?? '').toLowerCase().contains(query) ||
          (repo.language ?? '').toLowerCase().contains(query);
    }).toList();
  }

  List<GitHubRepositoryItem> _sortRepositories(List<GitHubRepositoryItem> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      return switch (_sortMode) {
        SortMode.updated => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
        SortMode.stars => b.stars.compareTo(a.stars),
        SortMode.name => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      };
    });
    return sorted;
  }

  void _addSource() {
    setState(() {
      _sourceControllers.add(TextEditingController());
    });
  }

  void _removeSource(int index) {
    if (_sourceControllers.length <= 1) return;
    setState(() {
      _sourceControllers.removeAt(index).dispose();
    });
  }

  String _widthBucket(double width) {
    if (width < 700) return '<700';
    if (width < 1100) return '700-1099';
    return '>=1100';
  }

  int _columnCount(double width) {
    final autoBase = width < 420
        ? 1
        : width < 720
            ? 2
            : width < 1040
                ? 3
                : width < 1440
                    ? 4
                    : 5;
    final target = _densityMode.columnCount;
    return _autoColumns ? autoBase : target;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedPageWrapper(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = _columnCount(width);
          final filtered = _filteredRepositories;
          final effectiveDensity = _autoColumns
              ? DensityMode.fromColumnCount(columns)
              : _densityMode;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildControls(theme, width, effectiveDensity),
                const SizedBox(height: 10),
                _buildStateBar(theme, width, columns, filtered.length, effectiveDensity),
                const SizedBox(height: 10),
                if (_error != null) _buildErrorBanner(theme),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: _animateTransitions
                      ? const Duration(milliseconds: 220)
                      : Duration.zero,
                  transitionBuilder: _animateTransitions
                      ? _animatedTransitionBuilder
                      : AnimatedSwitcher.defaultTransitionBuilder,
                  child: _loading
                      ? _buildLoadingState(key: const ValueKey('loading'))
                      : filtered.isEmpty
                          ? _buildEmptyState(key: const ValueKey('empty'))
                          : switch (_layoutMode) {
                              LayoutMode.grid => _buildGrid(
                                  filtered, columns, effectiveDensity,
                                  key: ValueKey(_animateTransitions ? 'grid-$columns' : 'grid'),
                                ),
                              LayoutMode.masonry => _buildMasonry(
                                  filtered, columns, effectiveDensity,
                                  key: ValueKey(_animateTransitions ? 'masonry-$columns' : 'masonry'),
                                ),
                              LayoutMode.list => _buildList(
                                  filtered, effectiveDensity,
                                  key: ValueKey(_animateTransitions ? 'list-$columns' : 'list'),
                                ),
                            },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _animatedTransitionBuilder(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }

  Widget _buildControls(ThemeData theme, double width, DensityMode effectiveDensity) {
    final compact = !_controlsExpanded;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, compact ? 10 : 16, 16, compact ? 10 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _controlsExpanded = !_controlsExpanded),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 0 : 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configuration',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (_controlsExpanded) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Tap to collapse sources, proxy, filter, sort, and layout.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (compact)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        'Collapsed',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Icon(
                    _controlsExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (_controlsExpanded) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adjust Columns',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Manual target columns',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<LayoutMode>(
                  segments: const [
                    ButtonSegment(value: LayoutMode.grid, label: Text('Grid'), icon: Icon(Icons.grid_view_rounded)),
                    ButtonSegment(value: LayoutMode.masonry, label: Text('Masonry'), icon: Icon(Icons.view_week_rounded)),
                    ButtonSegment(value: LayoutMode.list, label: Text('List'), icon: Icon(Icons.view_agenda_rounded)),
                  ],
                  selected: {_layoutMode},
                  onSelectionChanged: (value) => setState(() => _layoutMode = value.first),
                ),
                SegmentedButton<DensityMode>(
                  segments: const [
                    ButtonSegment(value: DensityMode.five, label: Text('5')),
                    ButtonSegment(value: DensityMode.four, label: Text('4')),
                    ButtonSegment(value: DensityMode.three, label: Text('3')),
                    ButtonSegment(value: DensityMode.two, label: Text('2')),
                    ButtonSegment(value: DensityMode.one, label: Text('1')),
                  ],
                  selected: {effectiveDensity},
                  onSelectionChanged: (value) => setState(() {
                    _densityMode = value.first;
                    _autoColumns = false;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<SortMode>(
                  value: _sortMode,
                  items: const [
                    DropdownMenuItem(value: SortMode.updated, child: Text('Sort: Updated')),
                    DropdownMenuItem(value: SortMode.stars, child: Text('Sort: Stars')),
                    DropdownMenuItem(value: SortMode.name, child: Text('Sort: Name')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortMode = value);
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: _autoColumns,
                      onChanged: (value) => setState(() {
                        _autoColumns = value;
                        if (value) {
                          _densityMode = DensityMode.fromColumnCount(_columnCount(width));
                        }
                      }),
                    ),
                    const SizedBox(width: 6),
                    const Text('Auto columns'),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: _animateTransitions,
                      onChanged: (value) => setState(() => _animateTransitions = value),
                    ),
                    const SizedBox(width: 6),
                    const Text('Animate transitions'),
                  ],
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Filter',
                      hintText: 'Search repo name / description',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _refresh,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(_loading ? 'Loading...' : 'Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSourceTable(theme),
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(
                  value: _useProxy,
                  onChanged: (value) => setState(() => _useProxy = value),
                ),
                const SizedBox(width: 6),
                const Text('Use proxy'),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _proxyController,
                    enabled: _useProxy,
                    decoration: const InputDecoration(
                      labelText: 'Proxy URL',
                      hintText: 'http://127.0.0.1:7890',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            if (_logs.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fetch Trace',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    for (final line in _logs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SelectableText(
                          line,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSourceTable(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Source URL')),
            DataColumn(label: Text('Kind')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: List.generate(_sourceControllers.length, (index) {
            final controller = _sourceControllers[index];
            final parsed = _tryParseSource(controller.text.trim());
            final status = parsed == null
                ? 'Invalid'
                : parsed.kind == GitHubRepositorySourceKind.user
                    ? 'User'
                    : 'Org';
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: controller,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: index == 0
                            ? 'https://github.com/VincentZyu233?tab=repositories'
                            : 'https://github.com/orgs/VincentZyuApps/repositories',
                        errorText: controller.text.trim().isEmpty || parsed != null
                            ? null
                            : 'Invalid GitHub repositories page',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                DataCell(Text(status)),
                DataCell(Text(parsed?.label ?? '-')),
                DataCell(
                  IconButton(
                    tooltip: 'Remove source',
                    onPressed: _sourceControllers.length <= 1 ? null : () => _removeSource(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  GitHubRepositorySource? _tryParseSource(String value) {
    try {
      return _service.parseSource(value);
    } catch (_) {
      return null;
    }
  }

  Widget _buildStateBar(ThemeData theme, double width, int columns, int count, DensityMode density) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          Text('Current columns: $columns'),
          Text('Gap: ${density.gap.toStringAsFixed(0)}'),
          Text('Width: ${width.round()}px'),
          Text('Range: ${_widthBucket(width)}'),
          Text('Layout: ${_layoutMode.name}'),
          Text(_autoColumns ? 'Adaptive columns: on' : 'Adaptive columns: off'),
          Text('Target columns: ${density.columnCount}'),
          Text('Repos: $count'),
          Text(_status),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _error!,
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }

  Widget _buildLoadingState({Key? key}) {
    return StateShell(
      key: key,
      icon: Icons.cloud_download_outlined,
      title: 'Loading repositories',
      subtitle: 'Fetching GitHub data and building the layout...',
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildEmptyState({Key? key}) {
    return StateShell(
      key: key,
      icon: Icons.inbox_outlined,
      title: 'No repositories to show',
      subtitle: 'Try a different filter or refresh the sources.',
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildGrid(List<GitHubRepositoryItem> items, int columns, DensityMode density, {Key? key}) {
    final gap = density.gap;
    return GridView.builder(
      key: key,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(gap),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
        childAspectRatio: columns >= 4 ? 2.9 : 2.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => RepositoryCard(
        repository: items[index],
        density: density,
        padding: density.cardPadding,
        radius: density.cardRadius,
        delayMs: 30 * index,
        onOpen: () => _openRepository(items[index].htmlUrl),
      ),
    );
  }

  Widget _buildMasonry(List<GitHubRepositoryItem> items, int columns, DensityMode density, {Key? key}) {
    final gap = density.gap;
    final buckets = List.generate(columns, (_) => <GitHubRepositoryItem>[]);
    for (var i = 0; i < items.length; i++) {
      buckets[i % columns].add(items[i]);
    }

    return Padding(
      key: key,
      padding: EdgeInsets.all(gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(columns, (columnIndex) {
          final columnItems = buckets[columnIndex];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: columnIndex == columns - 1 ? 0 : gap),
              child: Column(
                children: [
                  for (var i = 0; i < columnItems.length; i++) ...[
                    RepositoryCard(
                      repository: columnItems[i],
                      density: density,
                      padding: density.cardPadding,
                      radius: density.cardRadius,
                      delayMs: 35 * (columnIndex + i),
                      onOpen: () => _openRepository(columnItems[i].htmlUrl),
                    ),
                    SizedBox(height: gap),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildList(List<GitHubRepositoryItem> items, DensityMode density, {Key? key}) {
    final gap = density.gap;
    return ListView.separated(
      key: key,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(gap),
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: gap),
      itemBuilder: (context, index) => RepositoryListTile(
        repository: items[index],
        density: density,
        delayMs: 25 * index,
        onOpen: () => _openRepository(items[index].htmlUrl),
      ),
    );
  }

  Future<void> _openRepository(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
