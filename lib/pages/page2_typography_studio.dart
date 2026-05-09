import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/animated_page.dart';

class Page2TypographyStudio extends StatefulWidget {
  const Page2TypographyStudio({super.key});

  @override
  State<Page2TypographyStudio> createState() => _Page2TypographyStudioState();
}

enum _FontMode {
  systemDefault,
  googleFonts,
  localFile,
}

class _Page2TypographyStudioState extends State<Page2TypographyStudio> {
  static const _defaultSentence =
      '你好，The quick brown fox jumps over the lazy dog ✨🎨🦊';
  static const _paragraph =
      'Typography is not neutral. Weight, rhythm, spacing, and color all change how the same words feel on screen.';

  double _fontSize = 32;
  double _letterSpacing = 0;
  double _lineHeight = 1.5;
  Color _textColor = Colors.black87;
  _FontMode _fontMode = _FontMode.systemDefault;
  Brightness? _lastBrightness;

  bool _loadingLocalFont = false;
  String? _localFontFamily;
  String? _localFontStatus;

  final TextEditingController _fontPathController = TextEditingController();
  final TextEditingController _previewTextController =
      TextEditingController(text: _defaultSentence);

  static const _palette = <Color>[
    Colors.white,
    Color(0xFFF5F7FA),
    Colors.black87,
    Color(0xFF1F2937),
    Color(0xFF334155),
    Color(0xFF0F766E),
    Color(0xFF0369A1),
    Color(0xFF4338CA),
    Color(0xFF7C3AED),
    Color(0xFFBE185D),
    Color(0xFFB45309),
    Color(0xFFCA8A04),
    Color(0xFF15803D),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
  ];

  String get _rgbText => 'RGB(${_textColor.red}, ${_textColor.green}, ${_textColor.blue})';

  String get _hexText =>
      '#${_textColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  void dispose() {
    _fontPathController.dispose();
    _previewTextController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_lastBrightness != brightness) {
      _lastBrightness = brightness;
      _textColor = brightness == Brightness.dark ? Colors.white : Colors.black87;
    }
  }

  Future<void> _loadLocalFont() async {
    final path = _fontPathController.text.trim();
    if (path.isEmpty) {
      setState(() {
        _localFontStatus = 'Enter a local .ttf/.otf path first.';
      });
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      setState(() {
        _localFontStatus = 'Font file not found.';
      });
      return;
    }

    setState(() {
      _loadingLocalFont = true;
      _localFontStatus = 'Loading font file...';
    });

    try {
      final bytes = await file.readAsBytes();
      final family = 'LocalFont_${DateTime.now().millisecondsSinceEpoch}';
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      if (!mounted) return;
      setState(() {
        _localFontFamily = family;
        _fontMode = _FontMode.localFile;
        _localFontStatus = 'Loaded for this session: $path';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localFontStatus = 'Load failed: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingLocalFont = false;
      });
    }
  }

  Future<void> _pickLocalFontPath() async {
    const typeGroup = XTypeGroup(
      label: 'font',
      extensions: <String>['ttf', 'otf'],
      uniformTypeIdentifiers: <String>[
        'public.truetype-font',
        'public.opentype-font',
      ],
      mimeTypes: <String>[
        'font/ttf',
        'font/otf',
        'application/x-font-ttf',
        'application/x-font-otf',
      ],
    );

    try {
      final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (file == null || !mounted) return;
      setState(() {
        _fontPathController.text = file.path;
        _localFontStatus = 'Selected: ${file.name}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localFontStatus = 'File picker failed: $e';
      });
    }
  }

  TextStyle get _textStyle {
    switch (_fontMode) {
      case _FontMode.systemDefault:
        return TextStyle(
          fontSize: _fontSize,
          letterSpacing: _letterSpacing,
          height: _lineHeight,
        );
      case _FontMode.googleFonts:
        return GoogleFonts.playfairDisplay(
          fontSize: _fontSize,
          letterSpacing: _letterSpacing,
          height: _lineHeight,
        );
      case _FontMode.localFile:
        return TextStyle(
          fontFamily: _localFontFamily,
          fontSize: _fontSize,
          letterSpacing: _letterSpacing,
          height: _lineHeight,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewText = _previewTextController.text;

    return AnimatedPageWrapper(
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
                    previewText,
                    textAlign: TextAlign.center,
                    style: _textStyle.copyWith(color: _textColor),
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
                previewText.toUpperCase(),
                textAlign: TextAlign.center,
                style: _textStyle.copyWith(
                  color: _textColor.withValues(alpha: 0.6),
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
              onChanged: (value) => setState(() => _fontSize = value),
            ),
            _buildSlider(
              label: 'Letter Spacing',
              value: _letterSpacing,
              min: -2,
              max: 12,
              display: '${_letterSpacing.toStringAsFixed(1)} px',
              onChanged: (value) => setState(() => _letterSpacing = value),
            ),
            _buildSlider(
              label: 'Line Height',
              value: _lineHeight,
              min: 0.8,
              max: 3.0,
              display: '${_lineHeight.toStringAsFixed(2)}x',
              onChanged: (value) => setState(() => _lineHeight = value),
            ),
            const SizedBox(height: 12),
            RadioListTile<_FontMode>(
              title: const Text('System Default'),
              value: _FontMode.systemDefault,
              groupValue: _fontMode,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _fontMode = value);
              },
            ),
            RadioListTile<_FontMode>(
              title: const Text('Google Fonts – Playfair Display'),
              subtitle: const Text('Online packaged font from the Google Fonts plugin.'),
              value: _FontMode.googleFonts,
              groupValue: _fontMode,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _fontMode = value);
              },
            ),
            RadioListTile<_FontMode>(
              title: const Text('Local Font File'),
              subtitle: Text(
                _localFontStatus ?? 'Load one local font from disk for this session.',
              ),
              value: _FontMode.localFile,
              groupValue: _fontMode,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _fontMode = value);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fontPathController,
              decoration: InputDecoration(
                labelText: 'Local font path',
                hintText: '/path/to/local/font.ttf',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Clear path',
                      onPressed: () {
                        _fontPathController.clear();
                        setState(() {
                          _localFontStatus = 'Path cleared.';
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                    IconButton(
                      tooltip: 'Browse font file',
                      onPressed: _pickLocalFontPath,
                      icon: const Icon(Icons.folder_open_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _loadingLocalFont ? null : _loadLocalFont,
                  icon: _loadingLocalFont
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(_loadingLocalFont ? 'Loading...' : 'Load Local Font'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'One font at a time, session only.',
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _palette.map((color) {
                final selected = _textColor.value == color.value;
                final borderColor = color.computeLuminance() > 0.65
                    ? Colors.black26
                    : Colors.white70;
                return GestureDetector(
                  onTap: () => setState(() => _textColor = color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? borderColor : Colors.grey,
                        width: selected ? 3 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : const [],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                var tempColor = _textColor;
                final accepted = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Pick text color'),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: tempColor,
                          onColorChanged: (color) => tempColor = color,
                          enableAlpha: false,
                          displayThumbColor: true,
                          labelTypes: const [],
                          pickerAreaHeightPercent: 0.75,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Apply'),
                        ),
                      ],
                    );
                  },
                );
                if (accepted == true && mounted) {
                  setState(() => _textColor = tempColor);
                }
              },
              icon: const Icon(Icons.color_lens_outlined),
              label: const Text('Custom Color Picker'),
            ),
            const SizedBox(height: 8),
            Text(
              'Current: $_rgbText  $_hexText',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _previewTextController,
              maxLength: 100,
              minLines: 1,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Preview text',
                hintText: 'Type any text you want to preview',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            Text(
              'Live preview, 0-100 characters. Changes here update the typography preview above immediately.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
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
