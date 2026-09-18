import 'dart:typed_data';

import 'adjustments.dart';
import 'config.dart';
import 'dither.dart';
import 'effects.dart';
import 'grid.dart';
import 'image.dart';
import 'palette_gen.dart';
import 'palettes.dart';

class FilterResult {
  const FilterResult({required this.output, required this.grid, required this.palette});

  /// The full canvas at the requested output size.
  final RgbImage output;

  /// The low-res quantized grid (`gridCols x gridRows`).
  final RgbImage grid;

  /// The resolved palette as flat RGB. May contain padded or unused entries;
  /// in true-color mode it is the grid's unique colors.
  final Uint8List palette;

  int get paletteSize => palette.length ~/ 3;
}

Uint8List _packedToPalette(List<int> packed) {
  final out = Uint8List(packed.length * 3);
  for (var i = 0; i < packed.length; i++) {
    out[i * 3] = (packed[i] >> 16) & 0xFF;
    out[i * 3 + 1] = (packed[i] >> 8) & 0xFF;
    out[i * 3 + 2] = packed[i] & 0xFF;
  }
  return out;
}

/// The palette `config` quantizes onto, or `null` for true color.
Uint8List? resolvePalette(RgbImage grid, BitmapFilterConfig config) {
  switch (config.paletteMode) {
    case PaletteMode.fixed:
      return subsample(getPalette(config.fixedPalette!), config.nColors);
    case PaletteMode.custom:
      return subsample(_packedToPalette(config.customPalette!), config.nColors);
    case PaletteMode.auto:
      if (config.bitDepth >= kTrueColorThreshold) return null;
      return generatePalette(grid.data, config.nColors,
          algorithm: config.paletteAlgorithm);
  }
}

/// Run the full retro-bitmap pipeline.
///
/// Stages: adjustments → downsample to the grid → palette → dither →
/// upscale (+ gap) → scanlines. Unlike the Python reference there is no
/// Lanczos resize to the output canvas first: the source is downsampled to
/// the grid directly and `outputWidth x outputHeight` only governs the final
/// upscale (migration doc §6.1). Defaults to the source size.
///
/// `isCancelled` is polled per grid row in error diffusion and between
/// stages; when it fires the run throws [FilterCancelled].
FilterResult applyBitmapFilter(
  RgbImage source,
  BitmapFilterConfig config, {
  int? outputWidth,
  int? outputHeight,
  CancelCheck? isCancelled,
}) {
  config.validate();
  void checkCancelled() {
    if (isCancelled != null && isCancelled()) throw const FilterCancelled();
  }

  final adjusted = applyAdjustments(source,
      contrast: config.contrast, saturation: config.saturation, gamma: config.gamma);
  checkCancelled();
  final gridColors = downsample(adjusted, config.gridCols, config.gridRows,
      mode: config.blockSampling);
  checkCancelled();

  final palette = resolvePalette(gridColors, config);
  final RgbImage quantized;
  final Uint8List resolved;
  if (palette == null) {
    final unique = uniqueColors(gridColors.data);
    resolved = _packedToPalette(unique);
    quantized = gridColors;
  } else {
    resolved = palette;
    quantized = applyDither(gridColors, palette, config.dither,
        strength: config.ditherStrength,
        seed: config.randomSeed,
        isCancelled: isCancelled);
  }
  checkCancelled();

  var output = upscale(
    quantized,
    outputWidth ?? source.width,
    outputHeight ?? source.height,
    gapPx: config.gridGapPx,
    gapColor: [
      (config.gridGapColor >> 16) & 0xFF,
      (config.gridGapColor >> 8) & 0xFF,
      config.gridGapColor & 0xFF,
    ],
  );
  if (config.scanlines > 0) output = applyScanlines(output, config.scanlines);
  return FilterResult(output: output, grid: quantized, palette: resolved);
}
