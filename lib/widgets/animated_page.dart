import 'package:flutter/material.dart';

class AnimatedPageWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const AnimatedPageWrapper({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<AnimatedPageWrapper> createState() => _AnimatedPageWrapperState();
}

class _AnimatedPageWrapperState extends State<AnimatedPageWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: widget.curve);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: widget.child,
      ),
    );
  }
}

class StaggeredItem extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDelay;
  final Duration itemDuration;

  const StaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = const Duration(milliseconds: 60),
    this.itemDuration = const Duration(milliseconds: 400),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: itemDuration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final delay = index * baseDelay.inMilliseconds / itemDuration.inMilliseconds;
        final adjustedValue = (value - delay).clamp(0.0, 1.0);
        return Opacity(
          opacity: adjustedValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - adjustedValue)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class AnimatedSwitcher extends StatelessWidget {
  final Widget child;
  final Object key_;

  const AnimatedSwitcher({super.key, required this.child, required this.key_});

  @override
  Widget build(BuildContext context) {
    return _AnimatedSwitcherInternal(child: child, key: ValueKey(key_));
  }
}

class _AnimatedSwitcherInternal extends StatefulWidget {
  final Widget child;

  const _AnimatedSwitcherInternal({required this.child, super.key});

  @override
  State<_AnimatedSwitcherInternal> createState() => _AnimatedSwitcherInternalState();
}

class _AnimatedSwitcherInternalState extends State<_AnimatedSwitcherInternal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedSwitcherInternal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: widget.child,
    );
  }
}