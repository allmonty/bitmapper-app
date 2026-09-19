import 'package:flutter/widgets.dart';

import 'bevel.dart';
import 'button.dart';
import 'glyphs.dart';
import 'popup.dart';
import 'theme.dart';

/// An option of a [Win98Dropdown].
class Win98DropdownItem<T> {
  const Win98DropdownItem({required this.value, required this.label});
  final T value;
  final String label;
}

/// A drop-down combo box: a sunken field showing the selection, an arrow
/// button, a pop-up list, and Previous/Next buttons to step through
/// [items] without opening the list.
class Win98Dropdown<T> extends StatelessWidget {
  const Win98Dropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.maxListHeight = 260,
    this.semanticLabel,
  });

  final List<Win98DropdownItem<T>> items;
  final T? value;

  /// `null` disables the drop-down.
  final ValueChanged<T>? onChanged;
  final double maxListHeight;
  final String? semanticLabel;

  String get _label {
    for (final item in items) {
      if (item.value == value) return item.label;
    }
    return '';
  }

  /// Index of the current [value] in [items], or -1 if not found (or
  /// [value] is null).
  int get _index {
    for (var i = 0; i < items.length; i++) {
      if (items[i].value == value) return i;
    }
    return -1;
  }

  void _step(int delta) {
    if (items.isEmpty) return;
    final next = (_index + delta) % items.length;
    onChanged?.call(items[next < 0 ? next + items.length : next].value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    final enabled = onChanged != null;
    final canStep = enabled && items.length > 1;
    Widget stepButton(List<String> glyph, int delta, String label) => Win98Button(
      onPressed: canStep ? () => _step(delta) : null,
      minWidth: theme.scrollbarSize,
      minHeight: theme.controlHeight,
      padding: EdgeInsets.zero,
      semanticLabel: label,
      child: PixelGlyph(glyph, color: canStep ? theme.text : theme.disabledText, pixelSize: 1.5),
    );

    return Row(
      children: [
        Expanded(
          child: Win98PopupAnchor(
            matchWidth: true,
            builder: (context, isOpen, toggle) => Semantics(
              button: true,
              enabled: enabled,
              label: semanticLabel,
              value: _label,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: enabled ? toggle : null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: theme.controlHeight),
                  child: Bevel(
                    style: BevelStyle.field,
                    color: enabled ? theme.window : theme.face,
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              _label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: enabled ? theme.textStyle : theme.disabledTextStyle,
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Win98Button(
                            onPressed: enabled ? () {} : null,
                            minWidth: theme.scrollbarSize,
                            minHeight: theme.controlHeight - 4,
                            padding: EdgeInsets.zero,
                            child: PixelGlyph(
                              Win98Glyphs.arrowDown,
                              color: enabled ? theme.text : theme.disabledText,
                              pixelSize: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            popupBuilder: (context, close) => _DropdownList<T>(
              items: items,
              value: value,
              maxHeight: maxListHeight,
              onSelected: (v) {
                close();
                if (v != value) onChanged?.call(v);
              },
            ),
          ),
        ),
        const SizedBox(width: 2),
        stepButton(Win98Glyphs.arrowLeft, -1, 'Previous option'),
        const SizedBox(width: 2),
        stepButton(Win98Glyphs.arrowRight, 1, 'Next option'),
      ],
    );
  }
}

class _DropdownList<T> extends StatelessWidget {
  const _DropdownList({
    required this.items,
    required this.value,
    required this.maxHeight,
    required this.onSelected,
  });

  final List<Win98DropdownItem<T>> items;
  final T? value;
  final double maxHeight;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: theme.window,
        border: Border.all(color: theme.darkShadow),
      ),
      child: SingleChildScrollView(
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                Semantics(
                  button: true,
                  selected: item.value == value,
                  label: item.label,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(item.value),
                    child: Container(
                      color: item.value == value ? theme.selection : null,
                      constraints: BoxConstraints(minHeight: theme.controlHeight),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.label,
                        style: theme.textStyle.copyWith(
                          color: item.value == value ? theme.selectionText : theme.text,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
