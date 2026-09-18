import 'package:flutter/widgets.dart';

import 'bevel.dart';
import 'button.dart';
import 'dialog.dart';
import 'slider.dart';
import 'theme.dart';

/// The 48 "Basic colors" of the Win98 color picker.
const kWin98BasicColors = <int>[
  0xFF8080, 0xFFFF80, 0x80FF80, 0x00FF80, 0x80FFFF, 0x0080FF, 0xFF80C0, 0xFF80FF, //
  0xFF0000, 0xFFFF00, 0x80FF00, 0x00FF40, 0x00FFFF, 0x0080C0, 0x8080C0, 0xFF00FF, //
  0x804040, 0xFF8040, 0x00FF00, 0x008080, 0x004080, 0x8080FF, 0x800040, 0xFF0080, //
  0x800000, 0xFF8000, 0x008000, 0x008040, 0x0000FF, 0x0000A0, 0x800080, 0x8000FF, //
  0x400000, 0x804000, 0x004000, 0x004040, 0x000080, 0x000040, 0x400040, 0x400080, //
  0x000000, 0x808000, 0x808040, 0x808080, 0x408080, 0xC0C0C0, 0x400040, 0xFFFFFF,
];

/// Paint-style "Edit Colors" dialog. Resolves to the chosen color, or `null`
/// on cancel.
Future<Color?> showWin98ColorDialog({
  required BuildContext context,
  required Color initial,
  String title = 'Edit Colors',
  String okLabel = 'OK',
  String cancelLabel = 'Cancel',
}) {
  return showWin98Dialog<Color>(
    context: context,
    title: title,
    builder: (context) => Win98ColorPicker(
      initial: initial,
      okLabel: okLabel,
      cancelLabel: cancelLabel,
      onDone: (c) => Navigator.of(context).pop(c),
    ),
  );
}

/// The body of [showWin98ColorDialog]: basic-color swatches, R/G/B sliders
/// and a preview.
class Win98ColorPicker extends StatefulWidget {
  const Win98ColorPicker({
    super.key,
    required this.initial,
    required this.onDone,
    this.okLabel = 'OK',
    this.cancelLabel = 'Cancel',
  });

  final Color initial;

  /// Called with the chosen color, or `null` for cancel.
  final ValueChanged<Color?> onDone;
  final String okLabel;
  final String cancelLabel;

  @override
  State<Win98ColorPicker> createState() => _Win98ColorPickerState();
}

class _Win98ColorPickerState extends State<Win98ColorPicker> {
  late int _r = (widget.initial.r * 255).round();
  late int _g = (widget.initial.g * 255).round();
  late int _b = (widget.initial.b * 255).round();

  Color get _color => Color.fromARGB(255, _r, _g, _b);

  void _setRgb(int rgb) => setState(() {
    _r = (rgb >> 16) & 0xFF;
    _g = (rgb >> 8) & 0xFF;
    _b = rgb & 0xFF;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    final current = (_r << 16) | (_g << 8) | _b;
    Widget channel(String label, int value, ValueChanged<int> set) => Row(
      children: [
        SizedBox(width: 22, child: Text(label)),
        Expanded(
          child: Win98Slider(
            value: value.toDouble(),
            max: 255,
            divisions: 255,
            showTicks: false,
            semanticLabel: label,
            semanticFormatter: (v) => v.round().toString(),
            onChanged: (v) => setState(() => set(v.round())),
          ),
        ),
        SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.right)),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Basic colors:'),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (final rgb in kWin98BasicColors)
              Semantics(
                button: true,
                selected: rgb == current,
                label: '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}',
                child: GestureDetector(
                  onTap: () => _setRgb(rgb),
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: rgb == current ? theme.darkShadow : const Color(0x00000000),
                      ),
                    ),
                    child: Bevel(style: BevelStyle.field, color: Color(0xFF000000 | rgb)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 64,
              height: 48,
              child: Bevel(
                style: BevelStyle.field,
                color: _color,
                key: const Key('win98-color-preview'),
              ),
            ),
            const SizedBox(width: 8),
            Text('#${current.toRadixString(16).padLeft(6, '0').toUpperCase()}'),
          ],
        ),
        channel('R', _r, (v) => _r = v),
        channel('G', _g, (v) => _g = v),
        channel('B', _b, (v) => _b = v),
        Win98DialogButtons(
          children: [
            Win98Button(
              isDefault: true,
              onPressed: () => widget.onDone(_color),
              child: Text(widget.okLabel),
            ),
            Win98Button(onPressed: () => widget.onDone(null), child: Text(widget.cancelLabel)),
          ],
        ),
      ],
    );
  }
}
