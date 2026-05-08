import 'package:flutter/material.dart';
import '../widgets/animated_page.dart';

class Page7ControlsFeedback extends StatefulWidget {
  const Page7ControlsFeedback({super.key});

  @override
  State<Page7ControlsFeedback> createState() => _Page7ControlsFeedbackState();
}

class _Page7ControlsFeedbackState extends State<Page7ControlsFeedback>
    with SingleTickerProviderStateMixin {
  // Radio
  int _radioValue = 0;
  // Checkboxes
  bool _checkA = true;
  bool _checkB = false;
  bool _checkC = true;
  // Switches
  bool _switchA = true;
  bool _switchB = false;
  bool _switchC = true;
  // Progress
  bool _progressRunning = false;
  double _progressValue = 0;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _startProgress() async {
    if (_progressRunning) return;
    setState(() {
      _progressRunning = true;
      _progressValue = 0;
    });
    _spinController.repeat();

    for (int i = 0; i <= 100; i += 1) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) setState(() => _progressValue = i / 100);
    }

    _spinController.stop();
    if (mounted) {
      setState(() => _progressRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing completed!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPageWrapper(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === Selection Controls ===
          _sectionTitle('Selection Controls'),
          const SizedBox(height: 8),

          // Radio
          _subTitle('Radio Buttons'),
          Column(
            children: [
              Radio<int>(
                value: 0,
                groupValue: _radioValue,
                onChanged: (v) => setState(() => _radioValue = v!),
              ),
              Radio<int>(
                value: 1,
                groupValue: _radioValue,
                onChanged: (v) => setState(() => _radioValue = v!),
              ),
              Radio<int>(
                value: 2,
                groupValue: _radioValue,
                onChanged: (v) => setState(() => _radioValue = v!),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Checkboxes
          _subTitle('Checkboxes'),
          CheckboxListTile(
            title: const Text('Option A'),
            value: _checkA,
            onChanged: (v) => setState(() => _checkA = v!),
          ),
          CheckboxListTile(
            title: const Text('Option B'),
            value: _checkB,
            onChanged: (v) => setState(() => _checkB = v!),
          ),
          CheckboxListTile(
            title: const Text('Option C'),
            value: _checkC,
            onChanged: (v) => setState(() => _checkC = v!),
          ),

          const SizedBox(height: 12),

          // Switches
          _subTitle('Switches'),
          SwitchListTile(
            title: const Text('Enable Feature A'),
            value: _switchA,
            onChanged: (v) => setState(() => _switchA = v),
          ),
          SwitchListTile(
            title: const Text('Enable Feature B'),
            value: _switchB,
            onChanged: (v) => setState(() => _switchB = v),
          ),
          SwitchListTile(
            title: const Text('Enable Feature C'),
            value: _switchC,
            onChanged: (v) => setState(() => _switchC = v),
          ),

          const Divider(height: 40),

          // === Progress Feedback ===
          _sectionTitle('Progress Feedback'),
          const SizedBox(height: 12),

          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _progressRunning ? null : _startProgress,
                icon: Icon(_progressRunning ? Icons.hourglass_top : Icons.play_arrow),
                label: Text(_progressRunning ? 'Processing...' : 'Start Process'),
              ),
              const SizedBox(width: 16),
              if (_progressRunning)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Linear progress
          Text(
            'Linear: ${(_progressValue * 100).round()}%',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progressValue,
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 16),

          // Circular progress
          Row(
            children: [
              RotationTransition(
                turns: _spinController,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
              const SizedBox(width: 16),
              Text(_progressRunning ? 'Spinning...' : 'Idle'),
            ],
          ),

          const Divider(height: 40),

          // === Feedback Actions ===
          _sectionTitle('Feedback Actions'),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('This is a SnackBar message'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Show SnackBar'),
              ),
              OutlinedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Info'),
                      content: const Text('This is a simple dialog.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
              FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Action completed!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Floating SnackBar'),
              ),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm'),
                      content: const Text('Are you sure you want to proceed?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Confirm Dialog'),
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _subTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
