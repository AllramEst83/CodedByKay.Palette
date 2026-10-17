import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/color_utils.dart';

/// Simple RGB + hex color picker dialog. Returns `#rrggbb` or null if cancelled.
Future<String?> showColorPickerDialog(BuildContext context, String initialHex) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => _ColorPickerDialog(initialHex: initialHex),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initialHex});

  final String initialHex;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late int _argb = parseHexColor(widget.initialHex, fallback: 0xFF0F172A);
  late final TextEditingController _hexController =
      TextEditingController(text: argbToHex(_argb));

  int get _r => (_argb >> 16) & 0xFF;
  int get _g => (_argb >> 8) & 0xFF;
  int get _b => _argb & 0xFF;

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _setChannels(int r, int g, int b) {
    setState(() {
      _argb = 0xFF000000 | (r << 16) | (g << 8) | b;
      _hexController.text = argbToHex(_argb);
    });
  }

  void _onHexChanged(String value) {
    final String cleaned = value.replaceFirst('#', '');
    if (cleaned.length != 6 || int.tryParse(cleaned, radix: 16) == null) return;
    setState(() => _argb = parseHexColor(cleaned));
  }

  Widget _channel(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: <Widget>[
        SizedBox(width: 20, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            label: '$value',
            semanticFormatterCallback: (double v) => '$label ${v.round()}',
            onChanged: (double v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.end)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom background'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              label: 'Selected color ${argbToHex(_argb)}',
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Color(_argb),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _channel('R', _r, (int v) => _setChannels(v, _g, _b)),
            _channel('G', _g, (int v) => _setChannels(_r, v, _b)),
            _channel('B', _b, (int v) => _setChannels(_r, _g, v)),
            TextField(
              controller: _hexController,
              decoration: const InputDecoration(labelText: 'Hex', prefixText: ''),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                LengthLimitingTextInputFormatter(7),
              ],
              onChanged: _onHexChanged,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, argbToHex(_argb).toLowerCase()),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
