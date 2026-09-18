import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/editor_model.dart';
import '../../models/labels.dart';
import '../custom_palette_editor.dart';
import 'labeled_slider.dart';

class PaletteTab extends StatelessWidget {
  const PaletteTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editor = context.watch<EditorModel>();
    final config = editor.config;
    final mode = config.paletteMode;
    final maxStop = mode == PaletteMode.auto ? kTrueColorStop : kMaxPaletteBitDepth;

    return Win98ScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Win98GroupBox(
            label: l10n.paletteMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (m, label) in [
                  (PaletteMode.auto, l10n.paletteAuto),
                  (PaletteMode.fixed, l10n.paletteFixed),
                  (PaletteMode.custom, l10n.paletteCustom),
                ])
                  Win98Radio<PaletteMode>(
                    value: m,
                    groupValue: mode,
                    label: label,
                    onChanged: editor.setPaletteMode,
                  ),
              ],
            ),
          ),
          kControlGap,
          if (mode == PaletteMode.auto) ...[
            Text(l10n.paletteAlgorithm),
            Win98Dropdown<String>(
              semanticLabel: l10n.paletteAlgorithm,
              value: config.paletteAlgorithm,
              items: [
                Win98DropdownItem(value: 'median_cut', label: l10n.algoMedianCut),
                Win98DropdownItem(value: 'kmeans', label: l10n.algoKmeans),
              ],
              onChanged: editor.trueColor ? null : editor.setPaletteAlgorithm,
            ),
          ],
          if (mode == PaletteMode.fixed) ...[
            Text(l10n.fixedPalette),
            Win98Dropdown<String>(
              semanticLabel: l10n.fixedPalette,
              value: config.fixedPalette,
              items: [
                for (final name in listPalettes())
                  Win98DropdownItem(
                    value: name,
                    label: '${paletteLabel(name)} (${paletteLength(getPalette(name))})',
                  ),
              ],
              onChanged: editor.setFixedPalette,
            ),
            const SizedBox(height: 6),
            PaletteSwatches(
              colors: _packed(subsample(getPalette(config.fixedPalette!), config.nColors)),
            ),
          ],
          if (mode == PaletteMode.custom)
            CustomPaletteEditor(
              colors: config.customPalette ?? kDefaultCustomPalette,
              onChanged: editor.setCustomPalette,
            ),
          kControlGap,
          Win98GroupBox(
            label: l10n.colorsGroup,
            // Auto mode: 1–12 bits, then a final "true color" stop.
            child: LabeledSlider(
              label: editor.trueColor
                  ? l10n.trueColor
                  : l10n.bitDepth(config.bitDepth, config.nColors),
              value: editor.trueColor ? kTrueColorStop.toDouble() : config.bitDepth.toDouble(),
              min: 1,
              max: maxStop.toDouble(),
              divisions: maxStop - 1,
              onChanged: (v) => editor.setBitDepth(v.round()),
            ),
          ),
        ],
      ),
    );
  }

  static List<int> _packed(List<int> rgb) => [
    for (var i = 0; i < rgb.length; i += 3) (rgb[i] << 16) | (rgb[i + 1] << 8) | rgb[i + 2],
  ];
}
