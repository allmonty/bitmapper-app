import 'package:flutter/widgets.dart';

import 'bevel.dart';
import 'scroll.dart';
import 'theme.dart';

/// One row of a [Win98ListBox].
class Win98ListItem<T> {
  const Win98ListItem({required this.value, required this.label, this.leading});
  final T value;
  final String label;
  final Widget? leading;
}

/// A sunken white list with a navy selection highlight.
class Win98ListBox<T> extends StatelessWidget {
  const Win98ListBox({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.onActivated,
    this.height = 160,
  });

  final List<Win98ListItem<T>> items;
  final T? selected;
  final ValueChanged<T>? onSelected;

  /// Double-tap on a row (Win98's "open").
  final ValueChanged<T>? onActivated;

  /// Fixed height; `null` fills the parent (e.g. inside an `Expanded`).
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    return SizedBox(
      height: height ?? double.infinity,
      child: Bevel(
        style: BevelStyle.field,
        child: Win98ScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final item in items) _row(theme, item, item.value == selected)],
          ),
        ),
      ),
    );
  }

  Widget _row(Win98ThemeData theme, Win98ListItem<T> item, bool isSelected) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelected == null ? null : () => onSelected!(item.value),
        onDoubleTap: onActivated == null ? null : () => onActivated!(item.value),
        child: Container(
          constraints: BoxConstraints(minHeight: theme.controlHeight),
          color: isSelected ? theme.selection : null,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              if (item.leading != null) ...[item.leading!, const SizedBox(width: 6)],
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textStyle.copyWith(
                    color: isSelected ? theme.selectionText : theme.text,
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
