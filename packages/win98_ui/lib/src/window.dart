import 'package:flutter/widgets.dart';

import 'bevel.dart';
import 'button.dart';
import 'glyphs.dart';
import 'theme.dart';

/// A window: raised frame, gradient title bar with caption buttons, an
/// optional menu bar, the body, and an optional status bar.
class Win98Window extends StatelessWidget {
  const Win98Window({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.active = true,
    this.menuBar,
    this.statusBar,
    this.onMinimize,
    this.onMaximize,
    this.onClose,
    this.bodyPadding = const EdgeInsets.all(4),
    this.expand = false,
  });

  final String title;
  final Widget? icon;
  final bool active;
  final Widget? menuBar;
  final Widget? statusBar;

  /// Caption buttons are shown only for non-null callbacks.
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximize;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry bodyPadding;

  /// Fill the available height, pinning the status bar to the bottom (for
  /// a maximized main window). Dialogs leave this off to size to content.
  final bool expand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Bevel(
      style: BevelStyle.window,
      padding: const EdgeInsets.all(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Win98TitleBar(
            title: title,
            icon: icon,
            active: active,
            onMinimize: onMinimize,
            onMaximize: onMaximize,
            onClose: onClose,
          ),
          ?menuBar,
          Flexible(
            fit: expand ? FlexFit.tight : FlexFit.loose,
            child: Padding(padding: bodyPadding, child: child),
          ),
          ?statusBar,
        ],
      ),
    );
  }
}

/// The gradient title bar of a [Win98Window].
class Win98TitleBar extends StatelessWidget {
  const Win98TitleBar({
    super.key,
    required this.title,
    this.icon,
    this.active = true,
    this.onMinimize,
    this.onMaximize,
    this.onClose,
  });

  final String title;
  final Widget? icon;
  final bool active;
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximize;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    final size = theme.titleBarHeight - 6;
    Widget caption(List<String> glyph, VoidCallback onTap, String label) => Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Win98Button(
        onPressed: onTap,
        minWidth: size + 4,
        minHeight: size,
        padding: EdgeInsets.zero,
        semanticLabel: label,
        child: PixelGlyph(glyph, color: theme.text, pixelSize: 1.5),
      ),
    );

    return Container(
      height: theme.titleBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: active
              ? [theme.activeTitleStart, theme.activeTitleEnd]
              : [theme.inactiveTitleStart, theme.inactiveTitleEnd],
        ),
      ),
      child: Row(
        children: [
          if (icon != null) Padding(padding: const EdgeInsets.only(right: 4), child: icon),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.boldTextStyle.copyWith(color: theme.titleText),
            ),
          ),
          if (onMinimize != null) caption(Win98Glyphs.minimize, onMinimize!, 'Minimize'),
          if (onMaximize != null) caption(Win98Glyphs.maximize, onMaximize!, 'Maximize'),
          if (onClose != null) ...[
            const SizedBox(width: 2),
            caption(Win98Glyphs.close, onClose!, 'Close'),
          ],
        ],
      ),
    );
  }
}

/// A teal desktop background.
class Win98Desktop extends StatelessWidget {
  const Win98Desktop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Win98Theme.of(context).desktop, child: child);
}
