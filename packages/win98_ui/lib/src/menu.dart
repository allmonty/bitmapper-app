import 'package:flutter/widgets.dart';

import 'bevel.dart';
import 'popup.dart';
import 'theme.dart';

/// An entry of a [Win98Menu].
sealed class Win98MenuEntry {
  const Win98MenuEntry();
}

/// A selectable menu command. `onSelected == null` shows it disabled.
class Win98MenuItem extends Win98MenuEntry {
  const Win98MenuItem({required this.label, this.onSelected, this.shortcut, this.checked = false});

  final String label;
  final VoidCallback? onSelected;

  /// Right-aligned hint such as "Ctrl+S".
  final String? shortcut;
  final bool checked;
}

/// A horizontal separator line.
class Win98MenuDivider extends Win98MenuEntry {
  const Win98MenuDivider();
}

/// A top-level menu ("File", "Edit", ...).
class Win98Menu {
  const Win98Menu({required this.label, required this.items});
  final String label;
  final List<Win98MenuEntry> items;
}

/// The menu bar under a window's title bar.
class Win98MenuBar extends StatelessWidget {
  const Win98MenuBar({super.key, required this.menus});

  final List<Win98Menu> menus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      // Wraps onto a second line when narrow, as Win98 menu bars did.
      child: Wrap(children: [for (final menu in menus) _MenuBarButton(menu: menu)]),
    );
  }
}

class _MenuBarButton extends StatelessWidget {
  const _MenuBarButton({required this.menu});
  final Win98Menu menu;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    return Win98PopupAnchor(
      builder: (context, isOpen, toggle) => Semantics(
        button: true,
        label: menu.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: toggle,
          child: SizedBox(
            height: theme.controlHeight - 4,
            child: Center(
              widthFactor: 1,
              child: isOpen
                  ? Bevel(
                      style: BevelStyle.status,
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      child: Text(menu.label),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Text(menu.label),
                    ),
            ),
          ),
        ),
      ),
      popupBuilder: (context, close) => Win98MenuPanel(items: menu.items, onDismiss: close),
    );
  }
}

/// The raised drop-down panel listing menu entries. Also usable on its own,
/// e.g. as a context menu.
class Win98MenuPanel extends StatelessWidget {
  const Win98MenuPanel({super.key, required this.items, required this.onDismiss});

  final List<Win98MenuEntry> items;

  /// Called before an item's callback, to close the panel.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180),
      child: Bevel(
        style: BevelStyle.window,
        padding: const EdgeInsets.all(1),
        child: SingleChildScrollView(
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in items)
                  switch (entry) {
                    Win98MenuItem() => _MenuItemRow(item: entry, onDismiss: onDismiss),
                    Win98MenuDivider() => const _MenuDividerRow(),
                  },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuDividerRow extends StatelessWidget {
  const _MenuDividerRow();

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Column(
        children: [
          Container(height: 1, color: theme.shadow),
          Container(height: 1, color: theme.highlight),
        ],
      ),
    );
  }
}

class _MenuItemRow extends StatefulWidget {
  const _MenuItemRow({required this.item, required this.onDismiss});
  final Win98MenuItem item;
  final VoidCallback onDismiss;

  @override
  State<_MenuItemRow> createState() => _MenuItemRowState();
}

class _MenuItemRowState extends State<_MenuItemRow> {
  bool _hot = false;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    final item = widget.item;
    final enabled = item.onSelected != null;
    final hot = _hot && enabled;
    final style = !enabled
        ? theme.disabledTextStyle
        : theme.textStyle.copyWith(color: hot ? theme.selectionText : theme.text);

    return Semantics(
      button: true,
      enabled: enabled,
      checked: item.checked ? true : null,
      label: item.label,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hot = true),
        onExit: (_) => setState(() => _hot = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _hot = true),
          onTapCancel: () => setState(() => _hot = false),
          onTap: enabled
              ? () {
                  widget.onDismiss();
                  item.onSelected!();
                }
              : null,
          child: Container(
            color: hot ? theme.selection : null,
            constraints: BoxConstraints(minHeight: theme.controlHeight),
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: item.checked ? Text('✓', style: style, textAlign: TextAlign.center) : null,
                ),
                Expanded(child: Text(item.label, style: style)),
                if (item.shortcut != null) ...[
                  const SizedBox(width: 24),
                  Text(item.shortcut!, style: style),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
