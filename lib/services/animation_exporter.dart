import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';

import 'gif_io.dart';

/// Everything a GIF export needs. It carries the original GIF bytes rather
/// than the decoded frames: the worker decodes them itself (same caps as the
/// preview, so the frames are identical), which keeps the message small.
class GifExportJob {
  const GifExportJob({required this.gifBytes, required this.config, required this.size});

  final Uint8List gifBytes;

  /// The grid must already match the frames' aspect ratio (`configFor`).
  final BitmapFilterConfig config;
  final GifSize size;
}

class GifExportResult {
  const GifExportResult({required this.bytes, required this.frames, required this.lossyFrames});
  final Uint8List bytes;
  final int frames;

  /// Frames with more than 256 colors, quantized down by the GIF encoder.
  final int lossyFrames;
}

/// Thrown by an export's result future after [ExportTask.cancel].
class ExportCancelled implements Exception {
  const ExportCancelled();
  @override
  String toString() => 'ExportCancelled';
}

/// A running export: its result, and a way to stop it.
class ExportTask<T> {
  ExportTask(this.result, this._cancel);
  final Future<T> result;
  final void Function() _cancel;
  void cancel() => _cancel();
}

typedef ProgressCallback = void Function(int done, int total);
typedef GifExporter =
    ExportTask<GifExportResult> Function(GifExportJob job, ProgressCallback onProgress);

/// Filter every frame of the GIF in `job` and encode the result. Pure and
/// synchronous; [exportGifInIsolate] runs it off the UI thread.
GifExportResult exportGif(
  GifExportJob job, {
  ProgressCallback? onProgress,
  CancelCheck? isCancelled,
}) {
  final animation = decodeGif(job.gifBytes);
  if (animation == null) throw const FormatException('not a GIF');
  final config = job.config;
  final frames = animation.frames;
  final sources = paletteSourceFrames(config, frames.length);
  final palette = sources.isEmpty
      ? null
      : sequencePalette([for (final i in sources) frames[i]], config);
  final (width, height) = job.size.outputSize(
    animation.width,
    animation.height,
    config.gridCols,
    config.gridRows,
  );

  final writer = GifWriter(loopCount: animation.loopCount);
  RgbImage? held;
  for (var i = 0; i < frames.length; i++) {
    if (isCancelled != null && isCancelled()) throw const ExportCancelled();
    if (held == null || rendersFrame(config, i)) {
      final result = applyBitmapFilter(
        frames[i],
        config,
        outputWidth: width,
        outputHeight: height,
        palette: palette,
        seed: frameSeed(config, i),
        isCancelled: isCancelled,
      );
      held = result.output;
    }
    writer.addFrame(held, animation.durationsMs[i]);
    onProgress?.call(i + 1, frames.length);
  }
  return GifExportResult(
    bytes: writer.finish(),
    frames: writer.frameCount,
    lossyFrames: writer.lossyFrames,
  );
}

/// Run [exportGif] on a worker isolate, reporting progress. Cancelling kills
/// the worker immediately.
ExportTask<GifExportResult> exportGifInIsolate(GifExportJob job, ProgressCallback onProgress) {
  final port = ReceivePort();
  final completer = Completer<GifExportResult>();
  Isolate? isolate;
  var cancelled = false;

  void finish() {
    port.close();
    isolate?.kill(priority: Isolate.immediate);
  }

  port.listen((message) {
    if (completer.isCompleted) return;
    switch (message) {
      case ['progress', final int done, final int total]:
        onProgress(done, total);
      case ['done', final TransferableTypedData bytes, final int frames, final int lossy]:
        completer.complete(
          GifExportResult(
            bytes: bytes.materialize().asUint8List(),
            frames: frames,
            lossyFrames: lossy,
          ),
        );
        finish();
      case ['error', final String error]:
        completer.completeError(StateError(error));
        finish();
      case [final Object? error, final Object? _]: // from onError
        completer.completeError(StateError('$error'));
        finish();
    }
  });

  Isolate.spawn(_gifWorker, (port.sendPort, job), onError: port.sendPort).then(
    (spawned) {
      isolate = spawned;
      if (cancelled) finish();
    },
    onError: (Object e) {
      if (!completer.isCompleted) completer.completeError(e);
      port.close();
    },
  );

  return ExportTask(completer.future, () {
    if (completer.isCompleted) return;
    cancelled = true;
    completer.completeError(const ExportCancelled());
    finish();
  });
}

void _gifWorker((SendPort, GifExportJob) args) {
  final (port, job) = args;
  try {
    final result = exportGif(
      job,
      onProgress: (done, total) => port.send(['progress', done, total]),
    );
    port.send([
      'done',
      TransferableTypedData.fromList([result.bytes]),
      result.frames,
      result.lossyFrames,
    ]);
  } catch (e) {
    port.send(['error', '$e']);
  }
}
