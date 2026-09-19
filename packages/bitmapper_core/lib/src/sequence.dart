import 'dart:typed_data';

import 'adjustments.dart';
import 'config.dart';
import 'grid.dart';
import 'image.dart';
import 'palette_gen.dart';

/// Indices of `n` frames spread evenly over `frameCount` frames, always
/// starting with frame 0 (and ending with the last frame when n > 1).
List<int> sampleIndices(int frameCount, int n) {
  if (frameCount <= 0) return const [];
  if (n <= 1 || frameCount == 1) return const [0];
  if (n >= frameCount) return List<int>.generate(frameCount, (i) => i);
  return [for (var i = 0; i < n; i++) (i * (frameCount - 1)) ~/ (n - 1)];
}

/// Which frames the palette for an animation of `frameCount` frames is
/// built from, or an empty list when every frame gets its own palette (or
/// the palette does not depend on the image at all).
List<int> paletteSourceFrames(BitmapFilterConfig config, int frameCount) {
  if (!needsSequencePalette(config)) return const [];
  return switch (config.paletteStrategy) {
    PaletteStrategy.perFrame => const [],
    PaletteStrategy.firstFrame => frameCount > 0 ? const [0] : const [],
    PaletteStrategy.sampled => sampleIndices(frameCount, config.paletteSamples),
  };
}

/// Only auto palettes are generated from the image; fixed and custom ones
/// are the same for every frame, and true color has no palette.
bool needsSequencePalette(BitmapFilterConfig config) =>
    config.paletteMode == PaletteMode.auto && !config.isTrueColor;

/// One shared auto palette for an animation, built from `frames` (those
/// picked by [paletteSourceFrames]): each frame goes through the same
/// adjustments and grid downsample as the pipeline, the grids are pooled,
/// and one palette is generated from all of them.
///
/// Returns `null` when no shared palette applies (fixed/custom palettes,
/// true color, per-frame strategy, or no frames).
Uint8List? sequencePalette(List<RgbImage> frames, BitmapFilterConfig config) {
  if (frames.isEmpty ||
      !needsSequencePalette(config) ||
      config.paletteStrategy == PaletteStrategy.perFrame) {
    return null;
  }
  final grids = [
    for (final frame in frames)
      downsample(
        applyAdjustments(
          frame,
          contrast: config.contrast,
          saturation: config.saturation,
          gamma: config.gamma,
        ),
        config.gridCols,
        config.gridRows,
        mode: config.blockSampling,
      ).data,
  ];
  final pooled = Uint8List(grids.fold<int>(0, (n, g) => n + g.length));
  var offset = 0;
  for (final g in grids) {
    pooled.setRange(offset, offset + g.length, g);
    offset += g.length;
  }
  return generatePalette(pooled, config.nColors, algorithm: config.paletteAlgorithm);
}

/// The `random`-dither seed for frame `frameIndex`: the same for every
/// frame (static noise) unless `animateNoise` is on.
int frameSeed(BitmapFilterConfig config, int frameIndex) =>
    config.animateNoise ? config.randomSeed + frameIndex : config.randomSeed;
