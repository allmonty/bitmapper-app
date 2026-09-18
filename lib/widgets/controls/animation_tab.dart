import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/editor_model.dart';
import '../../models/media_model.dart';
import '../../services/gif_io.dart';
import 'labeled_slider.dart';

/// Settings that only matter for animations: how one palette is shared
/// across frames, noise animation, and the GIF export size.
class AnimationTab extends StatelessWidget {
  const AnimationTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Win98Theme.of(context);
    final editor = context.watch<EditorModel>();
    final media = context.watch<MediaModel>();
    final config = editor.config;
    final strategyApplies = needsSequencePalette(config);

    // Sizes shown next to the GIF size options.
    final frame = media.preview;
    final grid = frame == null ? config : editor.configFor(frame.width, frame.height);
    final (srcW, srcH) = frame == null ? (0, 0) : (frame.width, frame.height);
    final gifSize = editor.gifSize;
    final perCell = gifSize is GifSizePerCell ? gifSize.pixels : 4;
    final perCellIndex = kGifPixelsPerCell.indexOf(perCell).clamp(0, kGifPixelsPerCell.length - 1);

    return Win98ScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Win98GroupBox(
            label: l10n.paletteAcrossFrames,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (s, label) in [
                  (PaletteStrategy.firstFrame, l10n.strategyFirst),
                  (PaletteStrategy.sampled, l10n.strategySampled),
                  (PaletteStrategy.perFrame, l10n.strategyPerFrame),
                ])
                  Win98Radio<PaletteStrategy>(
                    value: s,
                    groupValue: config.paletteStrategy,
                    label: label,
                    onChanged: strategyApplies ? editor.setPaletteStrategy : null,
                  ),
                if (config.paletteStrategy == PaletteStrategy.sampled)
                  LabeledSlider(
                    label: l10n.paletteSamples(config.paletteSamples),
                    value: config.paletteSamples.toDouble(),
                    min: kMinPaletteSamples.toDouble(),
                    max: kMaxPaletteSamples.toDouble(),
                    divisions: kMaxPaletteSamples - kMinPaletteSamples,
                    onChanged: strategyApplies ? (v) => editor.setPaletteSamples(v.round()) : null,
                  ),
                if (!strategyApplies) Text(l10n.strategyOnlyAuto, style: theme.disabledTextStyle),
              ],
            ),
          ),
          if (config.dither == 'random')
            Win98Checkbox(
              value: config.animateNoise,
              label: l10n.animateNoise,
              onChanged: editor.setAnimateNoise,
            ),
          kControlGap,
          Win98GroupBox(
            label: l10n.gifSize,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Win98Radio<bool>(
                  value: false,
                  groupValue: gifSize is GifSizePerCell,
                  label: l10n.gifOriginal(srcW, srcH),
                  onChanged: (_) => editor.setGifSize(const GifSizeOriginal()),
                ),
                Win98Radio<bool>(
                  value: true,
                  groupValue: gifSize is GifSizePerCell,
                  label: l10n.gifPerCell,
                  onChanged: (_) => editor.setGifSize(GifSizePerCell(perCell)),
                ),
                if (gifSize is GifSizePerCell)
                  LabeledSlider(
                    label: l10n.gifPerCellValue(
                      perCell,
                      grid.gridCols * perCell,
                      grid.gridRows * perCell,
                    ),
                    value: perCellIndex.toDouble(),
                    min: 0,
                    max: (kGifPixelsPerCell.length - 1).toDouble(),
                    divisions: kGifPixelsPerCell.length - 1,
                    onChanged: (v) =>
                        editor.setGifSize(GifSizePerCell(kGifPixelsPerCell[v.round()])),
                  ),
                if (config.bitDepth > 8) Text(l10n.gifColorLimit, style: theme.disabledTextStyle),
              ],
            ),
          ),
          kControlGap,
          Text(l10n.animationFriendlyHint),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Win98Button(
              onPressed: editor.isAnimationFriendly ? null : editor.applyAnimationFriendly,
              child: Text(l10n.animationFriendly),
            ),
          ),
        ],
      ),
    );
  }
}
