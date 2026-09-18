import 'package:flutter/widgets.dart';

import 'button.dart';
import 'theme.dart';
import 'window.dart';

/// Show a modal Win98 dialog window. The title bar's close button pops
/// `null`. The caller's [Win98Theme] is carried into the dialog route.
Future<T?> showWin98Dialog<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  double maxWidth = 420,
}) {
  final theme = Win98Theme.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: title,
    barrierColor: const Color(0x33000000),
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, _, _) => Win98Theme(
      data: theme,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Win98Window(
                title: title,
                onClose: () => Navigator.of(dialogContext).pop(),
                bodyPadding: const EdgeInsets.all(10),
                child: Builder(builder: builder),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A right-aligned row of dialog buttons.
class Win98DialogButtons extends StatelessWidget {
  const Win98DialogButtons({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 6, children: children),
    );
  }
}

enum Win98MessageIconType { info, warning, error, question }

/// The classic message-box icons, painted.
class Win98MessageIcon extends StatelessWidget {
  const Win98MessageIcon(this.type, {super.key, this.size = 32});
  final Win98MessageIconType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    final (Color bg, Color fg, String glyph, bool triangle) = switch (type) {
      Win98MessageIconType.info => (const Color(0xFF0000FF), const Color(0xFFFFFFFF), 'i', false),
      Win98MessageIconType.question => (
        const Color(0xFF0000FF),
        const Color(0xFFFFFFFF),
        '?',
        false,
      ),
      Win98MessageIconType.error => (const Color(0xFFFF0000), const Color(0xFFFFFFFF), '×', false),
      Win98MessageIconType.warning => (const Color(0xFFFFFF00), const Color(0xFF000000), '!', true),
    };
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IconShapePainter(bg, triangle),
        child: Padding(
          padding: EdgeInsets.only(top: triangle ? size * 0.25 : 0),
          child: Center(
            child: Text(
              glyph,
              style: theme.boldTextStyle.copyWith(color: fg, fontSize: size * 0.6, height: 1),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconShapePainter extends CustomPainter {
  _IconShapePainter(this.color, this.triangle);
  final Color color;
  final bool triangle;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()..color = color;
    if (triangle) {
      final path = Path()
        ..moveTo(size.width / 2, 1)
        ..lineTo(size.width - 1, size.height - 1)
        ..lineTo(1, size.height - 1)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, outline);
    } else {
      final r = size.width / 2 - 1;
      // Drop shadow, then the disc.
      canvas.drawCircle(
        size.center(const Offset(2, 2)),
        r,
        Paint()..color = const Color(0x55000000),
      );
      canvas.drawCircle(size.center(Offset.zero), r, fill);
      canvas.drawCircle(size.center(Offset.zero), r, outline);
    }
  }

  @override
  bool shouldRepaint(_IconShapePainter old) => old.color != color || old.triangle != triangle;
}

/// Show a message box and return the index of the pressed button, or `null`
/// when closed from the title bar.
Future<int?> showWin98MessageBox({
  required BuildContext context,
  required String title,
  required String message,
  Win98MessageIconType icon = Win98MessageIconType.info,
  List<String> buttons = const ['OK'],
  int defaultIndex = 0,
}) {
  return showWin98Dialog<int>(
    context: context,
    title: title,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Win98MessageIcon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(padding: const EdgeInsets.only(top: 6), child: Text(message)),
            ),
          ],
        ),
        Win98DialogButtons(
          children: [
            for (var i = 0; i < buttons.length; i++)
              Win98Button(
                isDefault: i == defaultIndex,
                autofocus: i == defaultIndex,
                onPressed: () => Navigator.of(context).pop(i),
                child: Text(buttons[i]),
              ),
          ],
        ),
      ],
    ),
  );
}
