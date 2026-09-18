import 'package:flutter/widgets.dart';

import 'bevel.dart';
import 'focus_rect.dart';
import 'glyphs.dart';
import 'theme.dart';

/// Shared layout for a box/circle indicator followed by a tappable label.
class _LabeledToggle extends StatefulWidget {
  const _LabeledToggle({
    required this.indicator,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.semanticsChecked,
    this.inMutuallyExclusiveGroup = false,
  });

  final Widget indicator;
  final String? label;
  final bool enabled;
  final VoidCallback onTap;
  final bool semanticsChecked;
  final bool inMutuallyExclusiveGroup;

  @override
  State<_LabeledToggle> createState() => _LabeledToggleState();
}

class _LabeledToggleState extends State<_LabeledToggle> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    Widget? label = widget.label == null
        ? null
        : Text(widget.label!, style: widget.enabled ? theme.textStyle : theme.disabledTextStyle);
    if (label != null && _focused) label = FocusRect(child: label);

    return Semantics(
      checked: widget.semanticsChecked,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      enabled: widget.enabled,
      label: widget.label,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: theme.controlHeight),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.indicator,
                if (label != null) ...[const SizedBox(width: 6), Flexible(child: label)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A sunken square checkbox with an optional label.
class Win98Checkbox extends StatelessWidget {
  const Win98Checkbox({super.key, required this.value, required this.onChanged, this.label});

  final bool value;

  /// `null` disables the checkbox.
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    final enabled = onChanged != null;
    return _LabeledToggle(
      enabled: enabled,
      label: label,
      semanticsChecked: value,
      onTap: () => onChanged?.call(!value),
      indicator: SizedBox(
        width: 20,
        height: 20,
        child: Bevel(
          style: BevelStyle.field,
          color: enabled ? theme.window : theme.face,
          child: Center(
            child: value
                ? PixelGlyph(
                    Win98Glyphs.check,
                    color: enabled ? theme.text : theme.disabledText,
                    pixelSize: 2,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// A round radio button for one value of a group.
class Win98Radio<T> extends StatelessWidget {
  const Win98Radio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.label,
  });

  final T value;
  final T? groupValue;

  /// `null` disables the radio button.
  final ValueChanged<T>? onChanged;
  final String? label;

  bool get selected => value == groupValue;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    final enabled = onChanged != null;
    return _LabeledToggle(
      enabled: enabled,
      label: label,
      semanticsChecked: selected,
      inMutuallyExclusiveGroup: true,
      onTap: () => onChanged?.call(value),
      indicator: CustomPaint(
        size: const Size(20, 20),
        painter: _RadioPainter(theme: theme, selected: selected, enabled: enabled),
      ),
    );
  }
}

class _RadioPainter extends CustomPainter {
  _RadioPainter({required this.theme, required this.selected, required this.enabled});

  final Win98ThemeData theme;
  final bool selected;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const topLeftStart = 0.75 * 3.14159265, halfTurn = 3.14159265;
    canvas.drawOval(r.deflate(1), Paint()..color = enabled ? theme.window : theme.face);
    // Outer ring: shadow top-left, highlight bottom-right; inner ring:
    // dark shadow top-left, light bottom-right — the field bevel, but round.
    canvas.drawArc(r, topLeftStart, halfTurn, false, stroke(theme.shadow));
    canvas.drawArc(r, topLeftStart + halfTurn, halfTurn, false, stroke(theme.highlight));
    final inner = r.deflate(1);
    canvas.drawArc(inner, topLeftStart, halfTurn, false, stroke(theme.darkShadow));
    canvas.drawArc(inner, topLeftStart + halfTurn, halfTurn, false, stroke(theme.light));
    if (selected) {
      canvas.drawCircle(
        size.center(Offset.zero),
        size.width * 0.17,
        Paint()..color = enabled ? theme.text : theme.disabledText,
      );
    }
  }

  @override
  bool shouldRepaint(_RadioPainter old) =>
      old.selected != selected || old.enabled != enabled || old.theme != theme;
}
