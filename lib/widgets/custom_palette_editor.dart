import 'package:flutter/widgets.dart';
import 'package:win98_ui/win98_ui.dart';

import '../l10n/generated/app_localizations.dart';

/// A row of small color swatches.
class PaletteSwatches extends StatelessWidget {
  const PaletteSwatches({
    super.key,
    required this.colors,
    this.selected,
    this.onTap,
    this.size = 22,
  });

  /// Packed 0xRRGGBB colors.
  final List<int> colors;
  final int? selected;
  final ValueChanged<int>? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (var i = 0; i < colors.length; i++)
          Semantics(
            button: onTap != null,
            selected: i == selected,
            label: '#${colors[i].toRadixString(16).padLeft(6, '0').toUpperCase()}',
            child: GestureDetector(
              onTap: onTap == null ? null : () => onTap!(i),
              child: Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(1),
                color: i == selected ? theme.text : null,
                child: Bevel(style: BevelStyle.field, color: Color(0xFF000000 | colors[i])),
              ),
            ),
          ),
      ],
    );
  }
}

/// Edit a custom palette: tap a swatch to select it, then add, edit or
/// remove colors with the Win98 color dialog.
class CustomPaletteEditor extends StatefulWidget {
  const CustomPaletteEditor({super.key, required this.colors, required this.onChanged});

  final List<int> colors;
  final ValueChanged<List<int>> onChanged;

  static const maxColors = 256;

  @override
  State<CustomPaletteEditor> createState() => _CustomPaletteEditorState();
}

class _CustomPaletteEditorState extends State<CustomPaletteEditor> {
  int _selected = 0;

  int get _index => _selected.clamp(0, widget.colors.length - 1);

  Future<int?> _pick(int initial) async {
    final l10n = AppLocalizations.of(context);
    final color = await showWin98ColorDialog(
      context: context,
      initial: Color(0xFF000000 | initial),
      okLabel: l10n.ok,
      cancelLabel: l10n.cancel,
    );
    return color == null ? null : color.toARGB32() & 0xFFFFFF;
  }

  Future<void> _add() async {
    final rgb = await _pick(widget.colors[_index]);
    if (rgb == null) return;
    widget.onChanged([...widget.colors, rgb]);
    setState(() => _selected = widget.colors.length);
  }

  Future<void> _edit() async {
    final i = _index;
    final rgb = await _pick(widget.colors[i]);
    if (rgb == null) return;
    widget.onChanged([...widget.colors]..[i] = rgb);
  }

  void _remove() {
    widget.onChanged([...widget.colors]..removeAt(_index));
    setState(() => _selected = (_index - 1).clamp(0, widget.colors.length));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Win98GroupBox(
      label: l10n.customColors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaletteSwatches(
            colors: widget.colors,
            selected: _index,
            size: 30,
            onTap: (i) => setState(() => _selected = i),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Win98Button(
                onPressed: widget.colors.length < CustomPaletteEditor.maxColors ? _add : null,
                child: Text(l10n.addColor),
              ),
              Win98Button(onPressed: _edit, child: Text(l10n.editColor)),
              Win98Button(
                onPressed: widget.colors.length > 1 ? _remove : null,
                child: Text(l10n.removeColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
