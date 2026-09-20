// Stage-by-stage timing of the pipeline, on two scenarios that mirror the
// app's real preview and export requests (see FilterController.request /
// renderFull), to find which stage(s) actually dominate before assuming
// the whole pipeline needs optimizing (or a GPU rewrite). Complements
// benchmark.dart, which times the whole pipeline as one black box.
// Run AOT for realistic numbers:
//   dart compile exe tool/benchmark_stages.dart -o /tmp/bench_stages && /tmp/bench_stages
import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';

RgbImage randomImage(int width, int height, int seed) {
  final rng = XorShift128Plus(seed);
  final data = Uint8List(width * height * 3);
  for (var i = 0; i < data.length; i++) {
    data[i] = rng.nextInt64() & 0xFF;
  }
  return RgbImage(width, height, data);
}

void timeStage(String label, void Function() run) {
  final sw = Stopwatch()..start();
  run();
  print('  ${label.padRight(32)} ${sw.elapsedMilliseconds.toString().padLeft(5)} ms');
}

/// Runs every pipeline stage in order, feeding each stage's real output
/// forward, mirroring applyBitmapFilter's own sequence exactly
/// (pipeline.dart) so the numbers reflect real data flow, not synthetic
/// per-stage inputs.
void runScenario(
  String label,
  RgbImage source,
  BitmapFilterConfig config,
  int outputWidth,
  int outputHeight,
) {
  print(
    '\n-- $label (source ${source.width}x${source.height} -> '
    'grid ${config.gridCols}x${config.gridRows} -> '
    'output ${outputWidth}x$outputHeight) --',
  );

  late RgbImage adjusted;
  timeStage(
    'applyAdjustments',
    () => adjusted = applyAdjustments(
      source,
      contrast: config.contrast,
      saturation: config.saturation,
      gamma: config.gamma,
    ),
  );

  late RgbImage gridColors;
  timeStage(
    'downsample + applyShadeBands',
    () => gridColors = applyShadeBands(
      downsample(adjusted, config.gridCols, config.gridRows, mode: config.blockSampling),
      config.shadeBands,
    ),
  );

  late Uint8List palette;
  timeStage(
    'resolvePalette (${config.paletteAlgorithm})',
    () => palette = resolvePalette(gridColors, config)!,
  );
  // Compare both algorithms regardless of which one `config` picked, so we
  // know if kmeans is worth avoiding as a default.
  timeStage(
    'generatePalette (median_cut, for comparison)',
    () => generatePalette(gridColors.data, config.nColors, algorithm: 'median_cut'),
  );
  timeStage(
    'generatePalette (kmeans, for comparison)',
    () => generatePalette(gridColors.data, config.nColors, algorithm: 'kmeans'),
  );

  RgbImage? preDither;
  if (config.outline > 0) {
    timeStage(
      'nearestColor (pre-dither edge reference)',
      () => preDither = RgbImage(
        gridColors.width,
        gridColors.height,
        nearestColor(gridColors.data, palette),
      ),
    );
  }

  late RgbImage quantized;
  timeStage(
    'applyDither (${config.dither})',
    () => quantized = applyDither(
      gridColors,
      palette,
      config.dither,
      strength: config.ditherStrength,
      seed: config.randomSeed,
    ),
  );

  if (config.despeckle) {
    timeStage('despeckle', () => quantized = despeckle(quantized));
  }

  if (config.outline > 0) {
    timeStage(
      'applyOutline (${config.outlineMethod}, thickness ${config.outlineThickness}'
      '${config.outlineCloseGaps ? ', closeGaps' : ''})',
      () => quantized = applyOutline(
        quantized,
        palette,
        config.outline,
        method: config.outlineMethod,
        ink: config.outlineInk,
        edgeGrid: preDither,
        thickness: config.outlineThickness,
        closeGaps: config.outlineCloseGaps,
      ),
    );
  }

  late RgbImage output;
  timeStage(
    'upscale (+gap ${config.gridGapPx}px)',
    () => output = upscale(
      quantized,
      outputWidth,
      outputHeight,
      gapPx: config.gridGapPx,
      gapColor: unpackRgb(config.gridGapColor),
    ),
  );

  if (config.scanlines > 0) {
    timeStage('applyScanlines', () => applyScanlines(output, config.scanlines));
  }
}

void main() {
  // Preview: source capped at kPreviewDimension (see lib/services/
  // image_codec.dart), output size == grid size (near-free upscale), gap
  // and scanlines neutralized -- exactly what FilterController.request
  // sends.
  const previewConfig = BitmapFilterConfig(
    gridCols: 120,
    gridRows: 120,
    bitDepth: 4,
    dither: 'floyd_steinberg',
  );
  runScenario('Preview', randomImage(1024, 768, 1), previewConfig, 120, 120);

  // Export: full, uncapped source (~12MP phone photo), output size ==
  // source size, with a non-trivial config (gap, scanlines, sobel outline
  // with thickness + closeGaps) so the pricier optional stages actually
  // run -- what FilterController.renderFull sends.
  const exportConfig = BitmapFilterConfig(
    gridCols: 120,
    gridRows: 120,
    bitDepth: 4,
    dither: 'floyd_steinberg',
    gridGapPx: 1,
    scanlines: 0.2,
    outline: 0.8,
    outlineMethod: 'sobel',
    outlineThickness: 2,
    outlineCloseGaps: true,
  );
  final exportSource = randomImage(4000, 3000, 2);
  runScenario('Export', exportSource, exportConfig, exportSource.width, exportSource.height);
}
