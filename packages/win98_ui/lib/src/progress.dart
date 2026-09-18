import 'package:flutter/widgets.dart';

import 'bevel.dart';
import 'theme.dart';

/// A sunken progress bar filled with chunky blocks. `value == null` shows an
/// indeterminate marquee.
class Win98ProgressBar extends StatefulWidget {
  const Win98ProgressBar({super.key, this.value, this.height = 22});

  /// Progress in [0, 1], or `null` for indeterminate.
  final double? value;
  final double height;

  @override
  State<Win98ProgressBar> createState() => _Win98ProgressBarState();
}

class _Win98ProgressBarState extends State<Win98ProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(Win98ProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.value == null) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    return Semantics(
      value: widget.value == null ? null : '${(widget.value! * 100).round()}%',
      child: SizedBox(
        height: widget.height,
        child: Bevel(
          style: BevelStyle.status,
          padding: const EdgeInsets.all(2),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _BlocksPainter(
                color: theme.selection,
                value: widget.value,
                phase: _controller.value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlocksPainter extends CustomPainter {
  _BlocksPainter({required this.color, required this.value, required this.phase});

  final Color color;
  final double? value;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final blockW = (size.height * 0.6).clamp(6.0, 12.0);
    const gap = 2.0;
    final pitch = blockW + gap;
    final paint = Paint()..color = color;
    final count = (size.width / pitch).floor();
    if (value != null) {
      final filled = (count * value!.clamp(0.0, 1.0)).round();
      for (var i = 0; i < filled; i++) {
        canvas.drawRect(Rect.fromLTWH(i * pitch, 0, blockW, size.height), paint);
      }
    } else {
      // Three blocks sweeping across.
      final start = ((count + 3) * phase).floor() - 3;
      for (var i = start; i < start + 3; i++) {
        if (i >= 0 && i < count) {
          canvas.drawRect(Rect.fromLTWH(i * pitch, 0, blockW, size.height), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BlocksPainter old) =>
      old.value != value || old.phase != phase || old.color != color;
}
