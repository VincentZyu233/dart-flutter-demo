import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/github_repository_service.dart';
import '../widgets/animated_page.dart';

enum _LayoutMode { grid, masonry, list }
enum _DensityMode { five, four, three, two, one }
enum _SortMode { updated, stars, name }

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

  _LayoutMode _layoutMode = _LayoutMode.grid;
  _DensityMode _densityMode = _DensityMode.three;
  _SortMode _sortMode = _SortMode.updated;
  bool _useProxy = false;
  bool _controlsExpanded = false;

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
        _SortMode.updated => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
        _SortMode.stars => b.stars.compareTo(a.stars),
        _SortMode.name => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
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
    final base = width < 420
        ? 1
        : width < 720
            ? 2
            : width < 1040
                ? 3
                : width < 1440
                    ? 4
                    : 5;
    final target = switch (_densityMode) {
      _DensityMode.five => 5,
      _DensityMode.four => 4,
      _DensityMode.three => 3,
      _DensityMode.two => 2,
      _DensityMode.one => 1,
    };
    return math.min(base, target);
  }

  double get _gap => switch (_densityMode) {
        _DensityMode.five || _DensityMode.four => 10,
        _DensityMode.three => 14,
        _DensityMode.two || _DensityMode.one => 18,
      };

  EdgeInsets get _cardPadding => switch (_densityMode) {
        _DensityMode.five || _DensityMode.four => const EdgeInsets.all(10),
        _DensityMode.three => const EdgeInsets.all(14),
        _DensityMode.two || _DensityMode.one => const EdgeInsets.all(18),
      };

  double get _cardRadius => switch (_densityMode) {
        _DensityMode.five || _DensityMode.four => 12,
        _DensityMode.three => 16,
        _DensityMode.two || _DensityMode.one => 20,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedPageWrapper(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = _columnCount(width);
          final filtered = _filteredRepositories;

          return Column(
            children: [
              _buildControls(theme),
              const SizedBox(height: 10),
              _buildStateBar(theme, width, columns, filtered.length),
              const SizedBox(height: 10),
              if (_error != null) _buildErrorBanner(theme),
              const SizedBox(height: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _loading
                      ? _buildLoadingState(key: const ValueKey('loading'))
                          : filtered.isEmpty
                          ? _buildEmptyState(key: const ValueKey('empty'))
                          : switch (_layoutMode) {
                              _LayoutMode.grid => _buildGrid(filtered, columns, key: const ValueKey('grid')),
                              _LayoutMode.masonry => _buildMasonry(filtered, columns, key: const ValueKey('masonry')),
                              _LayoutMode.list => _buildList(filtered, key: const ValueKey('list')),
                            },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
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
                SegmentedButton<_LayoutMode>(
                  segments: const [
                    ButtonSegment(value: _LayoutMode.grid, label: Text('Grid'), icon: Icon(Icons.grid_view_rounded)),
                    ButtonSegment(value: _LayoutMode.masonry, label: Text('Masonry'), icon: Icon(Icons.view_week_rounded)),
                    ButtonSegment(value: _LayoutMode.list, label: Text('List'), icon: Icon(Icons.view_agenda_rounded)),
                  ],
                  selected: {_layoutMode},
                  onSelectionChanged: (value) => setState(() => _layoutMode = value.first),
                ),
                SegmentedButton<_DensityMode>(
                  segments: const [
                    ButtonSegment(value: _DensityMode.five, label: Text('5')),
                    ButtonSegment(value: _DensityMode.four, label: Text('4')),
                    ButtonSegment(value: _DensityMode.three, label: Text('3')),
                    ButtonSegment(value: _DensityMode.two, label: Text('2')),
                    ButtonSegment(value: _DensityMode.one, label: Text('1')),
                  ],
                  selected: {_densityMode},
                  onSelectionChanged: (value) => setState(() => _densityMode = value.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<_SortMode>(
                  value: _sortMode,
                  items: const [
                    DropdownMenuItem(value: _SortMode.updated, child: Text('Sort: Updated')),
                    DropdownMenuItem(value: _SortMode.stars, child: Text('Sort: Stars')),
                    DropdownMenuItem(value: _SortMode.name, child: Text('Sort: Name')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortMode = value);
                  },
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

  Widget _buildStateBar(ThemeData theme, double width, int columns, int count) {
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
          Text('Columns: $columns'),
          Text('Gap: ${_gap.toStringAsFixed(0)}'),
          Text('Width: ${width.round()}px'),
          Text('Range: ${_widthBucket(width)}'),
          Text('Layout: ${_layoutMode.name}'),
          Text(
            'Density: ${switch (_densityMode) {
              _DensityMode.five => 'target 5 columns',
              _DensityMode.four => 'target 4 columns',
              _DensityMode.three => 'target 3 columns',
              _DensityMode.two => 'target 2 columns',
              _DensityMode.one => 'target 1 column',
            }}',
          ),
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
    return _StateShell(
      key: key,
      icon: Icons.cloud_download_outlined,
      title: 'Loading repositories',
      subtitle: 'Fetching GitHub data and building the layout...',
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildEmptyState({Key? key}) {
    return _StateShell(
      key: key,
      icon: Icons.inbox_outlined,
      title: 'No repositories to show',
      subtitle: 'Try a different filter or refresh the sources.',
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildGrid(List<GitHubRepositoryItem> items, int columns, {Key? key}) {
    return GridView.builder(
      key: key,
      padding: EdgeInsets.all(_gap),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: _gap,
        mainAxisSpacing: _gap,
        childAspectRatio: columns >= 4 ? 1.2 : 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _RepositoryCard(
        repository: items[index],
        density: _densityMode,
        padding: _cardPadding,
        radius: _cardRadius,
        delayMs: 30 * index,
        onOpen: () => _openRepository(items[index].htmlUrl),
      ),
    );
  }

  Widget _buildMasonry(List<GitHubRepositoryItem> items, int columns, {Key? key}) {
    final buckets = List.generate(columns, (_) => <GitHubRepositoryItem>[]);
    for (var i = 0; i < items.length; i++) {
      buckets[i % columns].add(items[i]);
    }

    return SingleChildScrollView(
      key: key,
      padding: EdgeInsets.all(_gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(columns, (columnIndex) {
          final columnItems = buckets[columnIndex];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: columnIndex == columns - 1 ? 0 : _gap),
              child: Column(
                children: [
                  for (var i = 0; i < columnItems.length; i++) ...[
                    _RepositoryCard(
                      repository: columnItems[i],
                      density: _densityMode,
                      padding: _cardPadding,
                      radius: _cardRadius,
                      delayMs: 35 * (columnIndex + i),
                      onOpen: () => _openRepository(columnItems[i].htmlUrl),
                    ),
                    SizedBox(height: _gap),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildList(List<GitHubRepositoryItem> items, {Key? key}) {
    return ListView.separated(
      key: key,
      padding: EdgeInsets.all(_gap),
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: _gap),
      itemBuilder: (context, index) => _RepositoryListTile(
        repository: items[index],
        density: _densityMode,
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

class _RepositoryCard extends StatefulWidget {
  final GitHubRepositoryItem repository;
  final _DensityMode density;
  final EdgeInsets padding;
  final double radius;
  final int delayMs;
  final VoidCallback onOpen;

  const _RepositoryCard({
    required this.repository,
    required this.density,
    required this.padding,
    required this.radius,
    required this.delayMs,
    required this.onOpen,
  });

  @override
  State<_RepositoryCard> createState() => _RepositoryCardState();
}

class _RepositoryCardState extends State<_RepositoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = widget.repository;
    final scale = _hovered ? 1.02 : 1.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + widget.delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(widget.radius),
            elevation: _hovered ? 4 : 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.radius),
              onTap: widget.onOpen,
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.radius),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(repo.ownerAvatarUrl),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                repo.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                repo.source.label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      repo.description?.isNotEmpty == true
                          ? repo.description!
                          : 'No description provided.',
                      maxLines: widget.density == _DensityMode.one ? 4 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Tag(text: repo.fullName),
                        if (repo.language != null && repo.language!.isNotEmpty) _Tag(text: repo.language!),
                        _Tag(text: '★ ${repo.stars}'),
                        _Tag(text: '⑂ ${repo.forks}'),
                        if (repo.archived) const _Tag(text: 'Archived'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RepositoryListTile extends StatefulWidget {
  final GitHubRepositoryItem repository;
  final _DensityMode density;
  final int delayMs;
  final VoidCallback onOpen;

  const _RepositoryListTile({
    required this.repository,
    required this.density,
    required this.delayMs,
    required this.onOpen,
  });

  @override
  State<_RepositoryListTile> createState() => _RepositoryListTileState();
}

class _RepositoryListTileState extends State<_RepositoryListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = widget.repository;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + widget.delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hovered ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            onTap: widget.onOpen,
            leading: CircleAvatar(
              backgroundImage: NetworkImage(repo.ownerAvatarUrl),
            ),
            title: Text(
              repo.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
              subtitle: Text(
                repo.description?.isNotEmpty == true ? repo.description! : 'No description provided.',
                maxLines: widget.density == _DensityMode.one || widget.density == _DensityMode.two ? 3 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            trailing: Wrap(
              spacing: 6,
              children: [
                _Tag(text: '★ ${repo.stars}'),
                _Tag(text: repo.language ?? 'n/a'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _StateShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _StateShell({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
