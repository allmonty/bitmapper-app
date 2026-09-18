import 'package:flutter/widgets.dart';
import 'package:win98_ui/win98_ui.dart';

/// A caption above a [Win98Slider].
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: onChanged == null ? theme.disabledTextStyle : null),
        Win98Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          semanticLabel: label,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Vertical spacing between control groups.
const kControlGap = SizedBox(height: 8);
