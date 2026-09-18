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
  });

  final RgbImage source;
  final BitmapFilterConfig config;
  final int outputWidth;
  final int outputHeight;
}

typedef FilterRunner = Future<FilterResult> Function(FilterJob job);

/// Runs the pipeline on a background isolate (the migration doc's
/// recommendation): typed lists are copied over, the UI thread never blocks.
Future<FilterResult> runInIsolate(FilterJob job) => Isolate.run(
  () => applyBitmapFilter(
    job.source,
    job.config,
    outputWidth: job.outputWidth,
    outputHeight: job.outputHeight,
  ),
);

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
  RgbImage? _source;
  bool _disposed = false;

  /// Queue a render of `source` with `config` at the source's own size.
  void request(RgbImage source, BitmapFilterConfig config) {
    if (!identical(source, _source)) {
      _source = source;
      _generation++;
      _result = null;
    }
    _pending = FilterJob(
      source: source,
      config: config,
      outputWidth: source.width,
      outputHeight: source.height,
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
    _source = null;
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
