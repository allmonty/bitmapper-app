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
/// button, and a pop-up list.
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

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    final enabled = onChanged != null;
    return Win98PopupAnchor(
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
