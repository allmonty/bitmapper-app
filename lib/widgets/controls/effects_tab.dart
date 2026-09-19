import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/editor_model.dart';
import 'labeled_slider.dart';

/// Scanlines, plus the toon (cel shading) group: shade bands, stray-pixel
/// cleanup and ink outlines.
class EffectsTab extends StatelessWidget {
  const EffectsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editor = context.watch<EditorModel>();
    final config = editor.config;

    return Win98ScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledSlider(
            label: l10n.effectScanlines((config.scanlines * 100).round()),
            value: config.scanlines,
            min: 0,
            max: 1,
            divisions: 20,
            onChanged: editor.setScanlines,
          ),
          kControlGap,
          Win98GroupBox(
            label: l10n.toonGroup,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Slider stop 0 is "off"; stop k >= 1 means k + 1 bands.
                LabeledSlider(
                  label: config.shadeBands == 0
                      ? l10n.effectShadeBandsOff
                      : l10n.effectShadeBands(config.shadeBands),
                  value: config.shadeBands == 0 ? 0 : (config.shadeBands - 1).toDouble(),
                  min: 0,
                  max: (kMaxShadeBands - 1).toDouble(),
                  divisions: kMaxShadeBands - 1,
                  onChanged: (v) => editor.setShadeBands(v == 0 ? 0 : v.round() + 1),
                ),
                Win98Checkbox(
                  value: config.despeckle,
                  label: l10n.effectDespeckle,
                  onChanged: editor.setDespeckle,
                ),
                LabeledSlider(
                  label: l10n.effectOutline((config.outline * 100).round()),
                  value: config.outline,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  onChanged: editor.setOutline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
