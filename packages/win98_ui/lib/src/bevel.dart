import 'package:flutter/widgets.dart';

import 'theme.dart';

/// The border styles every Win98 control is built from.
enum BevelStyle {
  /// Buttons and raised panels: light top-left, dark bottom-right.
  raised,

  /// Window frames: like [raised] with the two top-left lines swapped.
  window,

  /// A button held down.
  pressed,

  /// Sunken fields (text boxes, list boxes, checkboxes).
  field,

  /// A shallow one-line sunken edge (status bar panes).
  status,

  /// Group-box frame: a shadow line with a highlight line inside it.
  etched,

  /// A single dark line all around (focused default button, menus).
  outline,
}

/// Paints a 2-pixel Win98 bevel (1 pixel for [BevelStyle.status]) around a
/// rectangle.
class BevelPainter extends CustomPainter {
  const BevelPainter({required this.style, required this.theme});

  final BevelStyle style;
  final Win98ThemeData theme;

  /// Width of the border drawn for `style`.
  static double widthOf(BevelStyle style) => switch (style) {
    BevelStyle.status || BevelStyle.outline => 1,
    _ => 2,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    switch (style) {
      case BevelStyle.raised:
        _frame(canvas, size, 0, t.highlight, t.darkShadow);
        _frame(canvas, size, 1, t.light, t.shadow);
      case BevelStyle.window:
        _frame(canvas, size, 0, t.light, t.darkShadow);
        _frame(canvas, size, 1, t.highlight, t.shadow);
      case BevelStyle.pressed:
        _frame(canvas, size, 0, t.darkShadow, t.highlight);
        _frame(canvas, size, 1, t.shadow, t.light);
      case BevelStyle.field:
        _frame(canvas, size, 0, t.shadow, t.highlight);
        _frame(canvas, size, 1, t.darkShadow, t.light);
      case BevelStyle.status:
        _frame(canvas, size, 0, t.shadow, t.highlight);
      case BevelStyle.etched:
        _frame(canvas, size, 0, t.shadow, t.highlight);
        _frame(canvas, size, 1, t.highlight, t.shadow);
      case BevelStyle.outline:
        _frame(canvas, size, 0, t.darkShadow, t.darkShadow);
    }
  }

  /// One 1px frame `inset` pixels in: `topLeft` on the top and left edges,
  /// `bottomRight` on the bottom and right edges.
  static void _frame(Canvas canvas, Size size, double inset, Color topLeft, Color bottomRight) {
    final w = size.width, h = size.height;
    if (w <= inset * 2 || h <= inset * 2) return;
    final tl = Paint()..color = topLeft;
    final br = Paint()..color = bottomRight;
    // Bottom/right drawn last so they own the shared corner pixels, as on
    // real Win98 controls.
    canvas.drawRect(Rect.fromLTWH(inset, inset, w - inset * 2, 1), tl);
    canvas.drawRect(Rect.fromLTWH(inset, inset, 1, h - inset * 2), tl);
    canvas.drawRect(Rect.fromLTWH(inset, h - inset - 1, w - inset * 2, 1), br);
    canvas.drawRect(Rect.fromLTWH(w - inset - 1, inset, 1, h - inset * 2), br);
  }

  @override
  bool shouldRepaint(BevelPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.theme != theme;
}

/// A box with a Win98 bevel border, a background color and padding inside
/// the border.
class Bevel extends StatelessWidget {
  const Bevel({
    super.key,
    this.style = BevelStyle.raised,
    this.color,
    this.padding = EdgeInsets.zero,
    this.child,
  });

  final BevelStyle style;

  /// Fill color; defaults to the theme's face color ([BevelStyle.field]
  /// defaults to the window color).
  final Color? color;

  /// Extra padding inside the border.
  final EdgeInsetsGeometry padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    final fill = color ?? (style == BevelStyle.field ? theme.window : theme.face);
    return CustomPaint(
      foregroundPainter: BevelPainter(style: style, theme: theme),
      child: ColoredBox(
        color: fill,
        child: Padding(
          padding: EdgeInsets.all(BevelPainter.widthOf(style)).add(padding),
          child: child,
        ),
      ),
    );
  }
}
