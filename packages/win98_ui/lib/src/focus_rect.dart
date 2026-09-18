import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Win98's dotted focus rectangle, drawn just inside the child.
class FocusRect extends StatelessWidget {
  const FocusRect({super.key, required this.child, this.padding = const EdgeInsets.all(1)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final color = Win98Theme.of(context).text;
    return CustomPaint(
      foregroundPainter: _DottedRectPainter(color),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DottedRectPainter extends CustomPainter {
  _DottedRectPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += 2) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, 1), paint);
      canvas.drawRect(Rect.fromLTWH(x, size.height - 1, 1, 1), paint);
    }
    for (var y = 0.0; y < size.height; y += 2) {
      canvas.drawRect(Rect.fromLTWH(0, y, 1, 1), paint);
      canvas.drawRect(Rect.fromLTWH(size.width - 1, y, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_DottedRectPainter old) => old.color != color;
}
