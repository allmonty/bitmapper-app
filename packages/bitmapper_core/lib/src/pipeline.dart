import 'dart:typed_data';

import 'adjustments.dart';
import 'color.dart';
import 'config.dart';
import 'dither.dart';
import 'effects.dart';
import 'grid.dart';
import 'image.dart';
import 'outline.dart';
import 'toon.dart';
import 'palette_gen.dart';
import 'palettes.dart';
import 'quantize.dart' show nearestColor;

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

/// The palette `config` quantizes onto, or `null` for true color.
Uint8List? resolvePalette(RgbImage grid, BitmapFilterConfig config) {
  switch (config.paletteMode) {
    case PaletteMode.fixed:
      return subsample(getPalette(config.fixedPalette!), config.nColors);
    case PaletteMode.custom:
      return subsample(paletteFromPacked(config.customPalette!), config.nColors);
    case PaletteMode.auto:
      if (config.bitDepth >= kTrueColorThreshold) return null;
      return generatePalette(grid.data, config.nColors, algorithm: config.paletteAlgorithm);
  }
}

/// Run the full retro-bitmap pipeline.
///
/// Stages: adjustments → downsample to the grid → palette → dither →
/// despeckle → outline → upscale (+ gap) → scanlines, with shade bands
/// right after the downsample. There is no resize to the output canvas
/// first: the source is downsampled to the grid directly and
/// `outputWidth x outputHeight` only governs the final upscale. Defaults to
/// the source size.
///
/// For animations, pass a precomputed `palette` (see `sequencePalette`) to
/// reuse one palette across frames instead of resolving it per frame, and a
/// per-frame `seed` (see `frameSeed`) for `random` dither.
///
/// `isCancelled` is polled per grid row in error diffusion and between
/// stages; when it fires the run throws [FilterCancelled].
FilterResult applyBitmapFilter(
  RgbImage source,
  BitmapFilterConfig config, {
  int? outputWidth,
  int? outputHeight,
  CancelCheck? isCancelled,
  Uint8List? palette,
  int? seed,
}) {
  config.validate();
  void checkCancelled() {
    if (isCancelled != null && isCancelled()) throw const FilterCancelled();
  }

  final adjusted = applyAdjustments(
    source,
    contrast: config.contrast,
    saturation: config.saturation,
    gamma: config.gamma,
  );
  checkCancelled();
  final gridColors = applyShadeBands(
    downsample(adjusted, config.gridCols, config.gridRows, mode: config.blockSampling),
    config.shadeBands,
  );
  checkCancelled();

  final resolvedPalette = palette ?? resolvePalette(gridColors, config);
  RgbImage quantized;
  final Uint8List resolved;
  RgbImage? preDither;
  if (resolvedPalette == null) {
    final unique = uniqueColors(gridColors.data);
    resolved = paletteFromPacked(unique);
    quantized = gridColors;
  } else {
    resolved = resolvedPalette;
    if (config.outline > 0) {
      preDither = RgbImage(
        gridColors.width,
        gridColors.height,
        nearestColor(gridColors.data, resolvedPalette),
      );
    }
    quantized = applyDither(
      gridColors,
      resolvedPalette,
      config.dither,
      strength: config.ditherStrength,
      seed: seed ?? config.randomSeed,
      isCancelled: isCancelled,
    );
  }
  if (config.despeckle) quantized = despeckle(quantized);
  if (config.outline > 0) {
    quantized = applyOutline(
      quantized,
      resolved,
      config.outline,
      method: config.outlineMethod,
      ink: config.outlineInk,
      edgeGrid: preDither,
      thickness: config.outlineThickness,
      closeGaps: config.outlineCloseGaps,
    );
  }
  checkCancelled();

  var output = upscale(
    quantized,
    outputWidth ?? source.width,
    outputHeight ?? source.height,
    gapPx: config.gridGapPx,
    gapColor: unpackRgb(config.gridGapColor),
  );
  if (config.scanlines > 0) output = applyScanlines(output, config.scanlines);
  return FilterResult(output: output, grid: quantized, palette: resolved);
}
