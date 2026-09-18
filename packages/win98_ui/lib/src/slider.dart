import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'bevel.dart';
import 'theme.dart';

/// A Win98 trackbar: a sunken groove, a pointed raised thumb, and optional
/// tick marks. Supports drag, tap-to-jump and arrow keys.
class Win98Slider extends StatefulWidget {
  const Win98Slider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.showTicks = true,
    this.semanticLabel,
    this.semanticFormatter,
  }) : assert(min < max);

  final double value;

  /// `null` disables the slider.
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;

  /// Number of discrete steps; values snap to them when set.
  final int? divisions;

  /// Draws a tick per division (when there are at most 40).
  final bool showTicks;
  final String? semanticLabel;
  final String Function(double value)? semanticFormatter;

  @override
  State<Win98Slider> createState() => _Win98SliderState();
}

class _Win98SliderState extends State<Win98Slider> {
  static const _thumbWidth = 14.0;
  static const _thumbHeight = 24.0;
  final _focusNode = FocusNode();
  double? _dragValue;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onChanged != null;

  double _snap(double v) {
    v = v.clamp(widget.min, widget.max);
    final d = widget.divisions;
    if (d == null || d <= 0) return v;
    final step = (widget.max - widget.min) / d;
    return widget.min + ((v - widget.min) / step).round() * step;
  }

  double _valueAt(double dx, double width) {
    final usable = width - _thumbWidth;
    final t = usable <= 0 ? 0.0 : ((dx - _thumbWidth / 2) / usable).clamp(0.0, 1.0);
    return _snap(widget.min + t * (widget.max - widget.min));
  }

  void _update(double v) {
    _dragValue = v;
    if (v != widget.value) widget.onChanged?.call(v);
  }

  void _end() {
    final v = _dragValue;
    _dragValue = null;
    if (v != null) widget.onChangeEnd?.call(v);
  }

  double get _keyStep {
    final d = widget.divisions;
    return d != null && d > 0 ? (widget.max - widget.min) / d : (widget.max - widget.min) / 20;
  }

  void _nudge(double delta) {
    final v = _snap(widget.value + delta);
    widget.onChanged?.call(v);
    widget.onChangeEnd?.call(v);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _nudge(_keyStep);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _nudge(-_keyStep);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    final fmt = widget.semanticFormatter ?? (v) => v.toStringAsFixed(2);
    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      enabled: _enabled,
      value: fmt(widget.value),
      increasedValue: fmt(_snap(widget.value + _keyStep)),
      decreasedValue: fmt(_snap(widget.value - _keyStep)),
      onIncrease: _enabled ? () => _nudge(_keyStep) : null,
      onDecrease: _enabled ? () => _nudge(-_keyStep) : null,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        canRequestFocus: _enabled,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _enabled
                  ? (d) {
                      _focusNode.requestFocus();
                      _update(_valueAt(d.localPosition.dx, width));
                    }
                  : null,
              onTapUp: _enabled ? (_) => _end() : null,
              onHorizontalDragStart: _enabled
                  ? (d) => _update(_valueAt(d.localPosition.dx, width))
                  : null,
              onHorizontalDragUpdate: _enabled
                  ? (d) => _update(_valueAt(d.localPosition.dx, width))
                  : null,
              onHorizontalDragEnd: _enabled ? (_) => _end() : null,
              child: CustomPaint(
                size: Size(width, 36),
                painter: _SliderPainter(
                  theme: theme,
                  t: (widget.value - widget.min) / (widget.max - widget.min),
                  ticks: widget.showTicks && (widget.divisions ?? 0) > 0 && widget.divisions! <= 40
                      ? widget.divisions!
                      : 0,
                  enabled: _enabled,
                  thumbWidth: _thumbWidth,
                  thumbHeight: _thumbHeight,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.theme,
    required this.t,
    required this.ticks,
    required this.enabled,
    required this.thumbWidth,
    required this.thumbHeight,
  });

  final Win98ThemeData theme;
  final double t;
  final int ticks;
  final bool enabled;
  final double thumbWidth;
  final double thumbHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final usable = size.width - thumbWidth;
    const grooveY = 10.0;
    // Groove: a 4px sunken channel.
    final groove = Rect.fromLTWH(thumbWidth / 2 - 2, grooveY, usable + 4, 4);
    canvas.save();
    canvas.translate(groove.left, groove.top);
    BevelPainter(style: BevelStyle.field, theme: theme).paint(canvas, groove.size);
    canvas.restore();

    // Ticks along the bottom.
    final tickPaint = Paint()..color = theme.text;
    for (var i = 0; i <= ticks && ticks > 0; i++) {
      final x = (thumbWidth / 2 + usable * i / ticks).floorToDouble();
      canvas.drawRect(Rect.fromLTWH(x, size.height - 5, 1, 4), tickPaint);
    }

    // Thumb: raised pentagon pointing down.
    final x0 = (usable * t.clamp(0.0, 1.0)).floorToDouble();
    final w = thumbWidth, h = thumbHeight, tip = w / 2;
    final body = Path()
      ..moveTo(x0, 0)
      ..lineTo(x0 + w, 0)
      ..lineTo(x0 + w, h - tip)
      ..lineTo(x0 + w / 2, h)
      ..lineTo(x0, h - tip)
      ..close();
    canvas.drawPath(body, Paint()..color = theme.face);
    Paint line(Color c) => Paint()
      ..color = c
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    // Top/left highlights, right/bottom shadows.
    canvas.drawLine(Offset(x0 + 0.5, h - tip), Offset(x0 + 0.5, 0.5), line(theme.highlight));
    canvas.drawLine(Offset(x0 + 0.5, 0.5), Offset(x0 + w - 1, 0.5), line(theme.highlight));
    canvas.drawLine(Offset(x0 + 0.5, h - tip), Offset(x0 + w / 2, h - 0.5), line(theme.highlight));
    canvas.drawLine(Offset(x0 + w - 0.5, 0), Offset(x0 + w - 0.5, h - tip), line(theme.darkShadow));
    canvas.drawLine(
      Offset(x0 + w - 0.5, h - tip),
      Offset(x0 + w / 2, h - 0.5),
      line(theme.darkShadow),
    );
    canvas.drawLine(Offset(x0 + w - 1.5, 1), Offset(x0 + w - 1.5, h - tip), line(theme.shadow));
    if (!enabled) {
      // Dither the thumb face to read as disabled.
      final dots = Paint()..color = theme.shadow;
      for (var y = 3.0; y < h - tip; y += 2) {
        for (var x = x0 + 2 + (y % 4 == 1 ? 1 : 0); x < x0 + w - 2; x += 2) {
          canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), dots);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.t != t || old.ticks != ticks || old.enabled != enabled || old.theme != theme;
}
