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

class _AdaptiveCard extends StatefulWidget {
  final int index;
  const _AdaptiveCard({required this.index});

  @override
  State<_AdaptiveCard> createState() => _AdaptiveCardState();
}

class _AdaptiveCardState extends State<_AdaptiveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  bool _pressed = false;

  late final Color _color;
  late final String _name;
  late final String _sentence;
  late final IconData _icon;

  @override
  void initState() {
    super.initState();
    final i = widget.index;
    _color = randomColor();
    _name = randomName();
    _sentence = randomSentence(words: 12);
    _icon = [
      Icons.image,
      Icons.landscape,
      Icons.pets,
      Icons.star,
      Icons.favorite,
      Icons.bolt,
    ][i % 6];

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
    setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    setState(() => _pressed = false);
  }

  void _onTapCancel() {
    _controller.reverse();
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: _pressed
                    ? _color.withOpacity(0.4)
                    : Colors.black.withOpacity(0.08),
                blurRadius: _pressed ? 16 : 4,
                spreadRadius: _pressed ? 2 : 0,
                offset: Offset(0, _pressed ? 4 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    color: _pressed ? Color.lerp(_color, Colors.white, 0.15) : _color,
                    child: Center(
                      child: AnimatedScale(
                        scale: _pressed ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOut,
                        child: Icon(
                          _icon,
                          size: 40,
                          color: Colors.white70,
                        ),
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
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 150),
                          style: Theme.of(context).textTheme.titleSmall!.copyWith(
                            fontWeight: _pressed ? FontWeight.bold : FontWeight.normal,
                          ),
                          child: Text('${_name} #${widget.index}'),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            _sentence,
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
          ),
        ),
      ),
    );
  }
}
