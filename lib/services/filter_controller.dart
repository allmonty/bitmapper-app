import 'dart:async';
import 'dart:isolate';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/foundation.dart';

/// Everything one pipeline run needs; sent to a background isolate.
class FilterJob {
  const FilterJob({
    required this.source,
    required this.config,
    required this.outputWidth,
    required this.outputHeight,
    this.palette,
    this.paletteFrames,
    this.seed,
  });

  final RgbImage source;
  final BitmapFilterConfig config;
  final int outputWidth;
  final int outputHeight;

  /// A shared animation palette to reuse as-is.
  final Uint8List? palette;

  /// Frames to build the shared animation palette from (when [palette] isn't
  /// known yet); see `sequencePalette`.
  final List<RgbImage>? paletteFrames;

  /// The `random`-dither seed for this frame.
  final int? seed;
}

/// Run one job: build the shared palette if asked to, then filter.
FilterResult runFilterJob(FilterJob job) {
  final frames = job.paletteFrames;
  final palette = job.palette ?? (frames == null ? null : sequencePalette(frames, job.config));
  return applyBitmapFilter(
    job.source,
    job.config,
    outputWidth: job.outputWidth,
    outputHeight: job.outputHeight,
    palette: palette,
    seed: job.seed,
  );
}

/// The frames of an animation and which one to render.
class AnimationContext {
  const AnimationContext({required this.frames, required this.frameIndex, this.document});

  /// Frames the shared palette is built from: every frame of a GIF, or the
  /// sampled frames of a video.
  final List<RgbImage> frames;

  /// Index of the rendered frame in the whole animation (for the noise seed).
  final int frameIndex;

  /// Identifies the animation; defaults to [frames].
  final Object? document;
}

typedef FilterRunner = Future<FilterResult> Function(FilterJob job);

/// Runs the pipeline on a background isolate (the migration doc's
/// recommendation): typed lists are copied over, the UI thread never blocks.
Future<FilterResult> runInIsolate(FilterJob job) => Isolate.run(() => runFilterJob(job));

/// Schedules preview renders.
///
/// - Requests are debounced, so a slider drag doesn't queue a run per frame.
/// - At most one run is in flight; while it runs, newer requests replace the
///   pending one (latest wins), which starts as soon as the current run ends.
/// - Results for a source that has since been replaced or cleared are
///   dropped (a generation counter tracks the source).
class FilterController extends ChangeNotifier {
  FilterController({
    FilterRunner runner = runInIsolate,
    this.debounce = const Duration(milliseconds: 120),
  }) : _runner = runner;

  final FilterRunner _runner;
  final Duration debounce;

  FilterResult? _result;
  FilterResult? get result => _result;

  Object? _error;
  Object? get error => _error;

  Duration? _lastDuration;
  Duration? get lastDuration => _lastDuration;

  bool _running = false;
  bool get busy => _running || _timer != null || _pending != null;

  FilterJob? _pending;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  /// The still image, or the frame list of an animation, being previewed.
  /// Scrubbing to another frame keeps the document (and the last result on
  /// screen); loading something else starts over.
  Object? _document;

  /// The shared animation palette and the palette-relevant config it was
  /// built for, so scrubbing and dither tweaks don't rebuild it.
  BitmapFilterConfig? _paletteKey;
  Uint8List? _sharedPalette;

  /// Queue a preview render of `source` with `config`: the result's grid
  /// (and output) is `gridCols x gridRows`, one pixel per cell, without gaps
  /// or scanlines. For animations, `animation` gives the frames (for the
  /// shared palette and the per-frame noise seed).
  void request(RgbImage source, BitmapFilterConfig config, {AnimationContext? animation}) {
    final document = animation?.document ?? animation?.frames ?? source;
    if (!identical(document, _document)) {
      _document = document;
      _generation++;
      _result = null;
      _paletteKey = null;
      _sharedPalette = null;
    }
    Uint8List? palette;
    List<RgbImage>? paletteFrames;
    int? seed;
    if (animation != null) {
      seed = frameSeed(config, animation.frameIndex);
      final sources = paletteSourceFrames(config, animation.frames.length);
      if (sources.isNotEmpty) {
        if (paletteKeyFor(config) == _paletteKey) {
          palette = _sharedPalette;
        } else {
          paletteFrames = [for (final i in sources) animation.frames[i]];
        }
      }
    }
    // Previews only need the quantized grid (one pixel per cell); the
    // preview paints cells, gaps and scanlines itself, so nothing is upscaled.
    _pending = FilterJob(
      source: source,
      config: config.copyWith(gridGapPx: 0, scanlines: 0),
      outputWidth: config.gridCols,
      outputHeight: config.gridRows,
      palette: palette,
      paletteFrames: paletteFrames,
      seed: seed,
    );
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      _drain();
    });
    notifyListeners();
  }

  /// Forget the current source and any pending work.
  void clear() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _document = null;
    _paletteKey = null;
    _sharedPalette = null;
    _generation++;
    _result = null;
    _error = null;
    _lastDuration = null;
    notifyListeners();
  }

  Future<void> _drain() async {
    if (_running) return; // the in-flight run picks up _pending when done
    while (_pending != null && !_disposed) {
      final job = _pending!;
      _pending = null;
      final generation = _generation;
      _running = true;
      notifyListeners();
      final stopwatch = Stopwatch()..start();
      try {
        final result = await _runner(job);
        if (_disposed) return;
        if (generation == _generation) {
          if (job.paletteFrames != null) {
            _paletteKey = paletteKeyFor(job.config);
            _sharedPalette = result.palette;
          }
          _result = result;
          _error = null;
          _lastDuration = stopwatch.elapsed;
        }
      } catch (e, stack) {
        if (_disposed) return;
        if (generation == _generation) _error = e;
        debugPrint('Filter failed: $e\n$stack');
      } finally {
        _running = false;
      }
      if (!_disposed) notifyListeners();
    }
  }

  /// Render `source` at full size, bypassing the preview queue (for export).
  Future<FilterResult> renderFull(RgbImage source, BitmapFilterConfig config) => _runner(
    FilterJob(
      source: source,
      config: config,
      outputWidth: source.width,
      outputHeight: source.height,
    ),
  );

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// The part of `config` a shared animation palette depends on; settings
/// applied after quantizing (dither, scanlines, gaps, noise) are neutralized
/// so changing them reuses the cached palette.
BitmapFilterConfig paletteKeyFor(BitmapFilterConfig config) => config.copyWith(
  dither: 'none',
  ditherStrength: 1,
  scanlines: 0,
  outline: 0,
  despeckle: false,
  gridGapPx: 0,
  gridGapColor: 0,
  randomSeed: 0,
  animateNoise: false,
);
