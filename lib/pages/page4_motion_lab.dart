import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/animated_page.dart';

class Page4MotionLab extends StatefulWidget {
  const Page4MotionLab({super.key});

  @override
  State<Page4MotionLab> createState() => _Page4MotionLabState();
}

class _Page4MotionLabState extends State<Page4MotionLab>
    with TickerProviderStateMixin {
  // --- controllers ---
  late final List<AnimationController> _entranceControllers;
  late final List<Animation<Offset>> _slideAnims;
  late final List<Animation<double>> _fadeAnims;

  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;

  final _usernameController = TextEditingController();
  String? _usernameError;
  double _submitProgress = 0;
  bool _isSubmitting = false;

  // --- interactive state ---
  double _sliderValue = 0.5;
  double _slider2Value = 0.3;
  bool _toggleA = true;
  bool _toggleB = false;
  int _segmentValue = 0;
  int _radioValue = 0;
  bool _checkboxA = true;
  bool _checkboxB = false;
  bool _checkboxC = true;
  int _selectedIndex = 0;
  double _dragValue = 0.0;

  static const _sectionCount = 9;

  @override
  void initState() {
    super.initState();

    _entranceControllers = List.generate(
      _sectionCount,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _slideAnims = _entranceControllers
        .map((c) => Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)))
        .toList();
    _fadeAnims = _entranceControllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(c))
        .toList();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _playEntrance();
  }

  Future<void> _playEntrance() async {
    for (final c in _entranceControllers) {
      c.forward();
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  @override
  void dispose() {
    for (final c in _entranceControllers) {
      c.dispose();
    }
    _pulseController.dispose();
    _shimmerController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // === animations ===

  Widget _slideIn(int index, Widget child) {
    return SlideTransition(
      position: _slideAnims[index],
      child: FadeTransition(
        opacity: _fadeAnims[index],
        child: child,
      ),
    );
  }

  // === builders ===

  Widget _sectionTitle(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
        ],
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedPageWrapper(
      child: SizedBox.expand(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _slideIn(0, _sectionTitle('Motion Lab', icon: Icons.animation)),
            const SizedBox(height: 8),
            _slideIn(0, Text(
              'Interactive UI components with animations',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )),
            const SizedBox(height: 20),

            // --- Segment 1: Pulse & Shimmer ---
            _slideIn(1, _sectionTitle('Pulse & Shimmer', icon: Icons.auto_awesome)),
            const SizedBox(height: 12),
            _slideIn(1, _buildPulseShimmer()),
            const SizedBox(height: 24),

            // --- Segment 2: Form with validation ---
            _slideIn(2, _sectionTitle('Form Validation', icon: Icons.edit_note)),
            const SizedBox(height: 12),
            _slideIn(2, _buildForm()),
            const SizedBox(height: 24),

            // --- Segment 3: Sliders ---
            _slideIn(3, _sectionTitle('Sliders', icon: Icons.tune)),
            const SizedBox(height: 12),
            _slideIn(3, _buildSliders()),
            const SizedBox(height: 24),

            // --- Segment 4: Switches & Chips ---
            _slideIn(4, _sectionTitle('Switches & Chips', icon: Icons.toggle_on)),
            const SizedBox(height: 12),
            _slideIn(4, _buildSwitchesAndChips()),
            const SizedBox(height: 24),

            // --- Segment 5: Segmented Control ---
            _slideIn(5, _sectionTitle('Segmented Control', icon: Icons.view_column)),
            const SizedBox(height: 12),
            _slideIn(5, _buildSegmentedControl()),
            const SizedBox(height: 24),

            // --- Segment 6: Radio & Checkbox ---
            _slideIn(6, _sectionTitle('Selection', icon: Icons.check_circle_outline)),
            const SizedBox(height: 12),
            _slideIn(6, _buildSelection()),
            const SizedBox(height: 24),

            // --- Segment 7: Animated Counter ---
            _slideIn(7, _sectionTitle('Animated Counter', icon: Icons.format_list_numbered)),
            const SizedBox(height: 12),
            _slideIn(7, _buildAnimatedCounter()),
            const SizedBox(height: 24),

            // --- Segment 8: Drag indicator ---
            _slideIn(8, _sectionTitle('Drag Indicator', icon: Icons.swipe)),
            const SizedBox(height: 12),
            _slideIn(8, _buildDragIndicator()),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
    );
  }

  // ===== Pulse & Shimmer =====

  Widget _buildPulseShimmer() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + _pulseController.value * 0.15;
                final glow = _pulseController.value;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(glow * 0.4),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.favorite, color: Colors.white),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (1.0 - _pulseController.value) * 0.15;
                final glow = 1.0 - _pulseController.value;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.tertiary.withOpacity(glow * 0.4),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final t = _pulseController.value;
                final color = Color.lerp(
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                  t,
                )!;
                return Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.palette, color: Colors.white),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              final t = _shimmerController.value;
              return Container(
                width: double.infinity,
                height: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.surfaceContainerHighest,
                      theme.colorScheme.primary.withOpacity(0.3),
                      theme.colorScheme.surfaceContainerHighest,
                    ],
                    stops: [
                      (t - 0.3).clamp(0.0, 1.0),
                      t.clamp(0.0, 1.0),
                      (t + 0.3).clamp(0.0, 1.0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ===== Form =====

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              onChanged: (v) {
                setState(() {
                  if (v.toLowerCase() == 'admin') {
                    _usernameError = 'Username already taken!';
                  } else if (v.isEmpty) {
                    _usernameError = 'Required';
                  } else {
                    _usernameError = null;
                  }
                });
              },
              decoration: InputDecoration(
                labelText: 'Username',
                prefixIcon: const Icon(Icons.person),
                errorText: _usernameError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isSubmitting
                    ? Row(
                        key: const ValueKey('loading'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Submitting... ${(_submitProgress * 100).round()}%'),
                        ],
                      )
                    : FilledButton(
                        key: const ValueKey('submit'),
                        onPressed: _handleSubmit,
                        child: const Text('Submit'),
                      ),
              ),
            ),
            if (_submitProgress > 0 && _submitProgress < 1.0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: _submitProgress, minHeight: 6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _submitProgress = 0;
    });
    for (int i = 0; i <= 100; i += 2) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (mounted) setState(() => _submitProgress = i / 100);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration complete!')),
      );
      setState(() {
        _isSubmitting = false;
        _submitProgress = 0;
      });
    }
  }

  // ===== Sliders =====

  Widget _buildSliders() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _sliderValue,
                    onChanged: (v) => setState(() => _sliderValue = v),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    (_sliderValue * 100).round().toString(),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: theme.sliderTheme.copyWith(
                      activeTrackColor: theme.colorScheme.tertiary,
                      thumbColor: theme.colorScheme.tertiary,
                      overlayColor: theme.colorScheme.tertiary.withOpacity(0.12),
                    ),
                    child: Slider(
                      value: _slider2Value,
                      onChanged: (v) => setState(() => _slider2Value = v),
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    (_slider2Value * 100).round().toString(),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final v1 = _sliderValue;
                final v2 = _slider2Value;
                final blend = Color.lerp(
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                  v2,
                )!;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40 + v1 * 60,
                      height: 40 + v1 * 60,
                      decoration: BoxDecoration(
                        color: blend,
                        borderRadius: BorderRadius.circular(8 + v1 * 20),
                      ),
                      child: Icon(
                        v1 > 0.7 ? Icons.sentiment_very_satisfied
                            : v1 > 0.4 ? Icons.sentiment_satisfied
                            : Icons.sentiment_dissatisfied,
                        color: Colors.white,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===== Switches & Chips =====

  Widget _buildSwitchesAndChips() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Feature Alpha'),
              subtitle: const Text('Enable experimental features'),
              value: _toggleA,
              onChanged: (v) => setState(() => _toggleA = v),
            ),
            SwitchListTile(
              title: const Text('Feature Beta'),
              subtitle: const Text('Enable dark mode override'),
              value: _toggleB,
              onChanged: (v) => setState(() => _toggleB = v),
            ),
            const Divider(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip('New', Icons.fiber_new, theme.colorScheme.primaryContainer, theme.colorScheme.onPrimaryContainer),
                _buildChip('Hot', Icons.local_fire_department, theme.colorScheme.errorContainer, theme.colorScheme.onErrorContainer),
                _buildChip('Trending', Icons.trending_up, theme.colorScheme.tertiaryContainer, theme.colorScheme.onTertiaryContainer),
                _buildChip('Verified', Icons.verified, theme.colorScheme.secondaryContainer, theme.colorScheme.onSecondaryContainer),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, Color bgColor, Color fgColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: FilterChip(
        label: Text(label),
        avatar: Icon(icon, size: 16),
        onSelected: (_) {},
        backgroundColor: bgColor.withOpacity(0.3),
        selectedColor: bgColor,
        labelStyle: TextStyle(color: fgColor),
      ),
    );
  }

  // ===== Segmented Control =====

  Widget _buildSegmentedControl() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Grid'), icon: Icon(Icons.grid_view)),
                ButtonSegment(value: 1, label: Text('List'), icon: Icon(Icons.view_list)),
                ButtonSegment(value: 2, label: Text('Map'), icon: Icon(Icons.map)),
              ],
              selected: {_segmentValue},
              onSelectionChanged: (v) => setState(() => _segmentValue = v.first),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _segmentValue == 0
                  ? _gridPreview(theme)
                  : _segmentValue == 1
                      ? _listPreview(theme)
                      : _mapPreview(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridPreview(ThemeData theme) {
    return GridView.count(
      key: const ValueKey('grid'),
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: List.generate(6, (i) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(Icons.image, color: theme.colorScheme.onPrimaryContainer, size: 24),
        ),
      )),
    );
  }

  Widget _listPreview(ThemeData theme) {
    return Column(
      key: const ValueKey('list'),
      children: List.generate(4, (i) => ListTile(
        leading: CircleAvatar(backgroundColor: theme.colorScheme.primaryContainer),
        title: Text('Item ${i + 1}'),
        subtitle: Text('Description for item ${i + 1}'),
        trailing: const Icon(Icons.chevron_right),
      )),
    );
  }

  Widget _mapPreview(ThemeData theme) {
    return Container(
      key: const ValueKey('map'),
      height: 120,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(Icons.explore, size: 48, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  // ===== Radio & Checkbox =====

  Widget _buildSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _radioItem(0, 'Option A'),
                _radioItem(1, 'Option B'),
                _radioItem(2, 'Option C'),
              ],
            ),
            const Divider(height: 32),
            CheckboxListTile(
              title: const Text('Enable notifications'),
              value: _checkboxA,
              onChanged: (v) => setState(() => _checkboxA = v!),
            ),
            CheckboxListTile(
              title: const Text('Auto-update'),
              value: _checkboxB,
              onChanged: (v) => setState(() => _checkboxB = v!),
            ),
            CheckboxListTile(
              title: const Text('Analytics'),
              value: _checkboxC,
              onChanged: (v) => setState(() => _checkboxC = v!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _radioItem(int value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<int>(
          value: value,
          groupValue: _radioValue,
          onChanged: (v) => setState(() => _radioValue = v!),
        ),
        GestureDetector(
          onTap: () => setState(() => _radioValue = value),
          child: Text(label),
        ),
      ],
    );
  }

  // ===== Animated Counter =====

  Widget _buildAnimatedCounter() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _counterButton(theme, Icons.remove, () {
                  setState(() => _selectedIndex = max(0, _selectedIndex - 1));
                }),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _selectedIndex.toDouble()),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Text(
                      value.round().toString(),
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    );
                  },
                ),
                _counterButton(theme, Icons.add, () {
                  setState(() => _selectedIndex = min(99, _selectedIndex + 1));
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _counterButton(ThemeData theme, IconData icon, VoidCallback onTap) {
    return Material(
      color: theme.colorScheme.primaryContainer,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
    );
  }

  // ===== Drag Indicator =====

  Widget _buildDragIndicator() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Drag the slider to see the indicator move', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragValue = (_dragValue + details.delta.dx / 300).clamp(0.0, 1.0);
                });
              },
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    AnimatedPositionedDirectional(
                      duration: const Duration(milliseconds: 50),
                      start: _dragValue * (300 - 60),
                      top: 10,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (_dragValue * 100).round().toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}