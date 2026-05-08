import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../widgets/animated_page.dart';

class Page6DataFeed extends StatefulWidget {
  const Page6DataFeed({super.key});

  @override
  State<Page6DataFeed> createState() => _Page6DataFeedState();
}

class _Page6DataFeedState extends State<Page6DataFeed> {
  bool _isGrid = false;
  final List<_FeedItem> _items = [];
  bool _isLoading = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_isLoading || _items.length >= 200) return;
    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _items.addAll(List.generate(
            20,
            (i) => _FeedItem(
              id: _items.length + i,
              name: randomName(),
              sentence: randomSentence(words: 15),
              color: randomColor(),
              icon: [
                Icons.star,
                Icons.bolt,
                Icons.favorite,
                Icons.auto_awesome,
                Icons.local_fire_department,
                Icons.diamond,
              ][(_items.length + i) % 6],
              liked: false,
            ),
          ));
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      _items.clear();
      _isLoading = false;
    });
    _loadMore();
  }

  void _toggleLike(int index) {
    setState(() {
      _items[index] = _items[index].copyWith(liked: !_items[index].liked);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPageWrapper(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_items.length} items',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view),
                  tooltip: _isGrid ? 'List view' : 'Grid view',
                  onPressed: () => setState(() => _isGrid = !_isGrid),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: _isGrid ? _buildGrid() : _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _items.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _ListCard(
          item: _items[index],
          onLike: () => _toggleLike(index),
          onTap: () => _openDetail(context, index),
        );
      },
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      itemCount: _items.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Center(child: CircularProgressIndicator());
        }
        return _GridCard(
          item: _items[index],
          onLike: () => _toggleLike(index),
          onTap: () => _openDetail(context, index),
        );
      },
    );
  }

  void _openDetail(BuildContext context, int index) {
    final item = _items[index];
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, __) => _DetailPage(
          item: item,
          onLike: () => _toggleLike(index),
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
  }
}

class _FeedItem {
  final int id;
  final String name;
  final String sentence;
  final Color color;
  final IconData icon;
  final bool liked;

  _FeedItem({
    required this.id,
    required this.name,
    required this.sentence,
    required this.color,
    required this.icon,
    required this.liked,
  });

  _FeedItem copyWith({bool? liked}) => _FeedItem(
        id: id,
        name: name,
        sentence: sentence,
        color: color,
        icon: icon,
        liked: liked ?? this.liked,
      );
}

class _ListCard extends StatefulWidget {
  final _FeedItem item;
  final VoidCallback onLike;
  final VoidCallback onTap;
  const _ListCard({required this.item, required this.onLike, required this.onTap});

  @override
  State<_ListCard> createState() => _ListCardState();
}

class _ListCardState extends State<_ListCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              backgroundColor: widget.item.color,
              radius: 24,
              child: Icon(widget.item.icon, color: Colors.white),
            ),
            title: Text(widget.item.name),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.item.sentence,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    widget.item.liked ? Icons.favorite : Icons.favorite_border,
                    color: widget.item.liked ? Colors.red : null,
                  ),
                  onPressed: widget.onLike,
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridCard extends StatefulWidget {
  final _FeedItem item;
  final VoidCallback onLike;
  final VoidCallback onTap;
  const _GridCard({required this.item, required this.onLike, required this.onTap});

  @override
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  color: widget.item.color,
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(widget.item.icon, size: 32, color: Colors.white70),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: Icon(
                            widget.item.liked ? Icons.favorite : Icons.favorite_border,
                            color: widget.item.liked ? Colors.red : Colors.white70,
                            size: 20,
                          ),
                          onPressed: widget.onLike,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.item.name, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          widget.item.sentence,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPage extends StatelessWidget {
  final _FeedItem item;
  final VoidCallback onLike;

  const _DetailPage({required this.item, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(item.name, style: const TextStyle(shadows: [
                Shadow(color: Colors.black54, blurRadius: 4),
              ])),
              background: Container(
                color: item.color,
                child: Center(
                  child: Icon(item.icon, size: 80, color: Colors.white38),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: item.color,
                        child: Icon(item.icon, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: theme.textTheme.titleLarge),
                            Text('#${item.id}', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          item.liked ? Icons.favorite : Icons.favorite_border,
                          color: item.liked ? Colors.red : null,
                          size: 32,
                        ),
                        onPressed: onLike,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Details', style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(item.sentence, style: theme.textTheme.bodyLarge),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.label, size: 16),
                        label: Text('Tag ${item.id % 5}'),
                      ),
                      Chip(
                        avatar: const Icon(Icons.category, size: 16),
                        label: Text('Category ${item.id % 3}'),
                      ),
                      Chip(
                        avatar: Icon(item.icon, size: 16),
                        label: Text(item.name),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Feed'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}