import 'package:flutter/widgets.dart';

import 'bevel.dart';
import 'theme.dart';

/// An etched frame with a caption set into its top edge.
class Win98GroupBox extends StatelessWidget {
  const Win98GroupBox({
    super.key,
    required this.label,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(8, 14, 8, 8),
  });

  final String label;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    final half = theme.fontSize * 0.6;
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: half),
          child: CustomPaint(
            foregroundPainter: BevelPainter(style: BevelStyle.etched, theme: theme),
            child: Padding(padding: padding, child: child),
          ),
        ),
        Positioned(
          left: 8,
          top: 0,
          child: ColoredBox(
            color: theme.face,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(label, style: theme.textStyle.copyWith(height: 1.1)),
            ),
          ),
        ),
      ],
    );
  }
}
