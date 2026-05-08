import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../widgets/animated_page.dart';

class Page3AdaptiveGrid extends StatelessWidget {
  const Page3AdaptiveGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedPageWrapper(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          int crossAxisCount;
          if (width > 900) {
            crossAxisCount = 3;
          } else if (width > 600) {
            crossAxisCount = 2;
          } else {
            crossAxisCount = 1;
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  'Columns: $crossAxisCount  |  Width: ${width.round()}px',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: crossAxisCount == 1 ? 2.2 : 1.4,
                  ),
                  itemCount: 30,
                  itemBuilder: (context, index) {
                    return _AdaptiveCard(index: index);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdaptiveCard extends StatelessWidget {
  final int index;
  const _AdaptiveCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final color = randomColor();
    final name = randomName();
    final sentence = randomSentence(words: 12);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: Container(
              color: color,
              child: Center(
                child: Icon(
                  [
                    Icons.image,
                    Icons.landscape,
                    Icons.pets,
                    Icons.star,
                    Icons.favorite,
                    Icons.bolt,
                  ][index % 6],
                  size: 40,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name #$index',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      sentence,
                      maxLines: 3,
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
