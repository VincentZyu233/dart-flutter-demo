import 'package:flutter/material.dart';

class Page1DialogLab extends StatelessWidget {
  const Page1DialogLab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: () => _showModernDialog(context),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Open Modern Dialog'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showWin32Dialog(context),
            icon: const Icon(Icons.desktop_windows),
            label: const Text('Open Classic Dialog'),
          ),
        ],
      ),
    );
  }

  void _showModernDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Modern Dialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (ctx, a1, a2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, a1, a2) {
        return const _ModernDialog();
      },
    );
  }

  void _showWin32Dialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Win32 Dialog',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, a1, a2, child) {
        return Transform.scale(
          scale: a1.value,
          child: Opacity(opacity: a1.value, child: child),
        );
      },
      pageBuilder: (ctx, a1, a2) {
        return const _Win32Dialog();
      },
    );
  }
}

// ── Modern Dialog ──────────────────────────────────────────────────────────────

class _ModernDialog extends StatefulWidget {
  const _ModernDialog();

  @override
  State<_ModernDialog> createState() => _ModernDialogState();
}

class _ModernDialogState extends State<_ModernDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildHeader(theme),
                ),
              ),
              const SizedBox(height: 20),
              SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildFields(theme),
                ),
              ),
              const SizedBox(height: 24),
              SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildActions(theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.info_outline_rounded,
            color: theme.colorScheme.onPrimaryContainer,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Information',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'A description should be a short, complete sentence.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: 'Enter your name',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            labelText: 'Value',
            hintText: 'Enter a value',
            prefixIcon: const Icon(Icons.tag),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('OK'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// ── Win32 Classic Dialog ───────────────────────────────────────────────────────

class _Win32Dialog extends StatefulWidget {
  const _Win32Dialog();

  @override
  State<_Win32Dialog> createState() => _Win32DialogState();
}

class _Win32DialogState extends State<_Win32Dialog> {
  static const _winGray = Color(0xFFC0C0C0);
  static const _winBlue = Color(0xFF000080);
  static const _winDark = Color(0xFF808080);
  static const _winLight = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _winGray,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.black, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTitleBar(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuestionIcon(),
                  const SizedBox(width: 16),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      color: _winBlue,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.info, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'A Short title is Best',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _winButton(Icons.close, size: 14),
        ],
      ),
    );
  }

  Widget _buildQuestionIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: _winBlue,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(2, 2),
            blurRadius: 3,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'A description should be a short, complete sentence.',
          style: TextStyle(fontSize: 13, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        _winInsetField('Field 1'),
        const SizedBox(height: 8),
        _winInsetField('Field 2'),
        const SizedBox(height: 20),
        _buildButtons(),
      ],
    );
  }

  Widget _winInsetField(String label) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _winDark),
          left: BorderSide(color: _winDark),
          bottom: BorderSide(color: _winLight),
          right: BorderSide(color: _winLight),
        ),
      ),
      child: TextField(
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: InputBorder.none,
          hintText: label,
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _win32Button('OK', isPrimary: true),
        const SizedBox(width: 8),
        _win32Button('Cancel', isPrimary: false),
      ],
    );
  }

  Widget _win32Button(String text, {required bool isPrimary}) {
    return Builder(
      builder: (context) {
        return SizedBox(
          width: 80,
          height: 28,
          child: ElevatedButton(
            onPressed: () {
              if (isPrimary) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _winGray,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.black, width: 1),
                borderRadius: BorderRadius.zero,
              ),
              shadowColor: Colors.black,
            ),
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _winButton(IconData icon, {double size = 16}) {
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: size,
        icon: Icon(icon, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}