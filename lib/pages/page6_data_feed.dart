import 'package:flutter/material.dart';
import '../models/mock_data.dart';

class Page6DataFeed extends StatefulWidget {
  const Page6DataFeed({super.key});

  @override
  State<Page6DataFeed> createState() => _Page6DataFeedState();
}

class _Page6DataFeedState extends State<Page6DataFeed> {
  bool _isGrid = false;
  final List<_FeedItem> _items = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  void _loadMore() {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _items.addAll(List.generate(
            20,
            (i) => _FeedItem(
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
              ][_items.length % 6],
            ),
          ));
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_items.length} items loaded',
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
        // Content
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 600));
              setState(() {
                _items.clear();
                _loadMore();
              });
            },
            child: _isGrid ? _buildGrid() : _buildList(),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _items.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _ListCard(item: _items[index]);
      },
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        return _GridCard(item: _items[index]);
      },
    );
  }
}

class _FeedItem {
  final String name;
  final String sentence;
  final Color color;
  final IconData icon;

  _FeedItem({
    required this.name,
    required this.sentence,
    required this.color,
    required this.icon,
  });
}

class _ListCard extends StatelessWidget {
  final _FeedItem item;
  const _ListCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: item.color,
          radius: 24,
          child: Icon(item.icon, color: Colors.white),
        ),
        title: Text(item.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            item.sentence,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  final _FeedItem item;
  const _GridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              color: item.color,
              child: Icon(item.icon, size: 32, color: Colors.white70),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text(
                      item.sentence,
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
    );
  }
}
