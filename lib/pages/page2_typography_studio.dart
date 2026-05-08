import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/animated_page.dart';

class Page2TypographyStudio extends StatefulWidget {
  const Page2TypographyStudio({super.key});

  @override
  State<Page2TypographyStudio> createState() => _Page2TypographyStudioState();
}

class _Page2TypographyStudioState extends State<Page2TypographyStudio> {
  double _fontSize = 32;
  double _letterSpacing = 0;
  double _lineHeight = 1.5;
  bool _useCustomFont = false;
  Color _textColor = Colors.black87;

  static const _sentence = 'The quick brown fox jumps over the lazy dog';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedPageWrapper(
      child: SizedBox.expand(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 200),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  _sentence,
                  textAlign: TextAlign.center,
                  style: _textStyle.copyWith(
                    color: _textColor,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                _sentence.toUpperCase(),
                textAlign: TextAlign.center,
                style: _textStyle.copyWith(
                  color: _textColor.withOpacity(0.6),
                  fontSize: _fontSize * 0.6,
                ),
              ),
            ),

            const SizedBox(height: 32),

            _buildSlider(
              label: 'Font Size',
              value: _fontSize,
              min: 12,
              max: 72,
              display: '${_fontSize.round()} px',
              onChanged: (v) => setState(() => _fontSize = v),
            ),
            _buildSlider(
              label: 'Letter Spacing',
              value: _letterSpacing,
              min: -2,
              max: 12,
              display: '${_letterSpacing.toStringAsFixed(1)} px',
              onChanged: (v) => setState(() => _letterSpacing = v),
            ),
            _buildSlider(
              label: 'Line Height',
              value: _lineHeight,
              min: 0.8,
              max: 3.0,
              display: '${_lineHeight.toStringAsFixed(2)}x',
              onChanged: (v) => setState(() => _lineHeight = v),
            ),

            const SizedBox(height: 12),

            SwitchListTile(
              title: const Text('Custom Serif Font'),
              subtitle: Text(
                _useCustomFont ? 'Google Fonts – Playfair Display' : 'System Default',
              ),
              value: _useCustomFont,
              onChanged: (v) => setState(() => _useCustomFont = v),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              children: [
                Colors.black87,
                Colors.blue,
                Colors.red,
                Colors.green,
                Colors.purple,
                Colors.orange,
              ].map((c) {
                final selected = _textColor == c;
                return GestureDetector(
                  onTap: () => setState(() => _textColor = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.grey,
                        width: selected ? 3 : 1,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)]
                          : [],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

  TextStyle get _textStyle {
    final base = _useCustomFont
        ? GoogleFonts.playfairDisplay(
            fontSize: _fontSize,
            letterSpacing: _letterSpacing,
            height: _lineHeight,
          )
        : TextStyle(
            fontSize: _fontSize,
            letterSpacing: _letterSpacing,
            height: _lineHeight,
          );
    return base;
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(display, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
