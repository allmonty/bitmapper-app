import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/editor_model.dart';
import 'labeled_slider.dart';

class AdjustTab extends StatelessWidget {
  const AdjustTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editor = context.watch<EditorModel>();
    final config = editor.config;
    String fmt(double v) => v.toStringAsFixed(2);

    return Win98ScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledSlider(
            label: l10n.adjustContrast(fmt(config.contrast)),
            value: config.contrast,
            min: 0,
            max: 2,
            divisions: 40,
            onChanged: editor.setContrast,
          ),
          kControlGap,
          LabeledSlider(
            label: l10n.adjustSaturation(fmt(config.saturation)),
            value: config.saturation,
            min: 0,
            max: 2,
            divisions: 40,
            onChanged: editor.setSaturation,
          ),
          kControlGap,
          LabeledSlider(
            label: l10n.adjustGamma(fmt(config.gamma)),
            value: config.gamma,
            min: 0.2,
            max: 3,
            divisions: 28,
            onChanged: editor.setGamma,
          ),
          kControlGap,
          Align(
            alignment: Alignment.centerLeft,
            child: Win98Button(onPressed: editor.resetAdjustments, child: Text(l10n.reset)),
          ),
        ],
      ),
    );
  }
}
