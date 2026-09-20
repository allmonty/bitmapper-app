import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/editor_model.dart';
import '../../models/media_model.dart';
import '../../services/gif_io.dart';
import '../../services/image_codec.dart';
import '../../services/video_exporter.dart';
import 'labeled_slider.dart';

/// The source frame rate frame-skip holds against: the video's own rate, or
/// a GIF's average frame rate from its per-frame delays. Null if unknown
/// (no media loaded, or a GIF with no frames).
double? _sourceFps(MediaModel media) {
  if (media.isVideo) return media.videoInfo?.frameRate;
  final durations = media.animation?.durationsMs;
  if (durations == null || durations.isEmpty) return null;
  final avgMs = durations.reduce((a, b) => a + b) / durations.length;
  return avgMs > 0 ? 1000 / avgMs : null;
}

/// `12` for a whole number, `7.5` for a fractional one.
String _formatFps(double fps) {
  final rounded = (fps * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(1);
}

/// Settings that only matter for animations: how one palette is shared
/// across frames, noise animation, frame skip, and the GIF export size.
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
    // A GIF made from video is read at most kMaxAnimationDimension wide.
    final (srcW, srcH) = frame == null
        ? (0, 0)
        : media.isVideo
        ? fitWithin(frame.width, frame.height, kMaxAnimationDimension)
        : (frame.width, frame.height);
    final gifSize = editor.gifSize;
    final perCell = gifSize is GifSizePerCell ? gifSize.pixels : 4;
    final perCellIndex = kGifPixelsPerCell.indexOf(perCell).clamp(0, kGifPixelsPerCell.length - 1);

    final sourceFps = _sourceFps(media);
    final effectiveFps = sourceFps == null ? null : sourceFps / (config.frameSkip + 1);
    final frameSkipLabel = effectiveFps == null
        ? (config.frameSkip == 0 ? l10n.frameSkipOff : l10n.frameSkip(config.frameSkip))
        : (config.frameSkip == 0
              ? l10n.frameSkipOffWithFps(_formatFps(effectiveFps))
              : l10n.frameSkipWithFps(config.frameSkip, _formatFps(effectiveFps)));

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
          LabeledSlider(
            label: frameSkipLabel,
            value: config.frameSkip.toDouble(),
            min: kMinFrameSkip.toDouble(),
            max: kMaxFrameSkip.toDouble(),
            divisions: kMaxFrameSkip - kMinFrameSkip,
            onChanged: (v) => editor.setFrameSkip(v.round()),
          ),
          kControlGap,
          if (media.isVideo) ...[
            Win98GroupBox(
              label: l10n.exportFormat,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (f, label) in [
                    (VideoFormat.mp4, l10n.formatMp4),
                    (VideoFormat.gif, l10n.formatGif),
                  ])
                    Win98Radio<VideoFormat>(
                      value: f,
                      groupValue: editor.videoFormat,
                      label: label,
                      onChanged: editor.setVideoFormat,
                    ),
                  if (media.videoInfo case final info? when info.hasAudio && !info.audioCompatible)
                    Text(l10n.audioUnsupportedShort, style: theme.disabledTextStyle),
                ],
              ),
            ),
            kControlGap,
          ],
          if (media.isVideo && editor.videoFormat == VideoFormat.mp4)
            Win98GroupBox(
              label: l10n.mp4Resolution,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (r, label) in [
                    (Mp4Resolution.original, l10n.resOriginal),
                    (Mp4Resolution.p720, l10n.res720),
                    (Mp4Resolution.p480, l10n.res480),
                  ])
                    Win98Radio<Mp4Resolution>(
                      value: r,
                      groupValue: editor.mp4Resolution,
                      label: label,
                      onChanged: editor.setMp4Resolution,
                    ),
                ],
              ),
            )
          else ...[
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
            if (media.isVideo)
              LabeledSlider(
                label: l10n.gifFrameRate(editor.gifFrameRate),
                value: kGifFrameRates
                    .indexOf(editor.gifFrameRate)
                    .clamp(0, kGifFrameRates.length - 1)
                    .toDouble(),
                min: 0,
                max: (kGifFrameRates.length - 1).toDouble(),
                divisions: kGifFrameRates.length - 1,
                onChanged: (v) => editor.setGifFrameRate(kGifFrameRates[v.round()]),
              ),
          ],
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
