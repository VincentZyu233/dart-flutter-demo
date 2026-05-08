import 'dart:math';
import 'package:flutter/material.dart';

class Page4MotionLab extends StatefulWidget {
  const Page4MotionLab({super.key});

  @override
  State<Page4MotionLab> createState() => _Page4MotionLabState();
}

class _Page4MotionLabState extends State<Page4MotionLab>
    with TickerProviderStateMixin {
  late final List<AnimationController> _fadeControllers;
  late final List<Animation<Offset>> _slideAnimations;
  late final List<Animation<double>> _fadeAnimations;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _usernameError;
  double _submitProgress = 0;
  bool _isSubmitting = false;
  bool _fabOpen = false;

  @override
  void initState() {
    super.initState();
    _fadeControllers = List.generate(
      5,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _slideAnimations = _fadeControllers
        .asMap()
        .entries
        .map((e) => Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: e.value,
              curve: Curves.easeOutCubic,
            )))
        .toList();

    _fadeAnimations = _fadeControllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(c))
        .toList();

    _playEntrance();
  }

  Future<void> _playEntrance() async {
    for (final c in _fadeControllers) {
      c.forward();
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void dispose() {
    for (final c in _fadeControllers) {
      c.dispose();
    }
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateUsername(String value) {
    setState(() {
      if (value.toLowerCase() == 'admin') {
        _usernameError = 'Username already taken!';
      } else if (value.isEmpty) {
        _usernameError = 'Required';
      } else {
        _usernameError = null;
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _animatedItem(0, _buildHeader()),
          const SizedBox(height: 20),
          _animatedItem(1, _buildTextField(
            controller: _usernameController,
            label: 'Username',
            icon: Icons.person,
            error: _usernameError,
            onChanged: _validateUsername,
          )),
          const SizedBox(height: 16),
          _animatedItem(2, _buildTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email,
          )),
          const SizedBox(height: 16),
          _animatedItem(3, _buildTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock,
            obscure: true,
          )),
          const SizedBox(height: 24),
          _animatedItem(4, Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSubmitting ? 'Submitting...' : 'Register'),
                ),
              ),
              if (_submitProgress > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _submitProgress,
                    minHeight: 6,
                  ),
                ),
              ],
            ],
          )),
        ],
      ),
    );
  }

  Widget _animatedItem(int index, Widget child) {
    return SlideTransition(
      position: _slideAnimations[index],
      child: FadeTransition(
        opacity: _fadeAnimations[index],
        child: child,
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'Create Account',
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? error,
    bool obscure = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        errorText: error,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// --- FAB overlay ---
// (integrated into page as an expandable FAB)
