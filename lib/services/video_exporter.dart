import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/services.dart';

import 'animation_exporter.dart';
import 'gif_io.dart';
import 'video_io.dart';

enum VideoFormat { mp4, gif }

/// MP4 output size, as a cap on the long edge.
enum Mp4Resolution {
  original(null),
  p720(1280),
  p480(854);

  const Mp4Resolution(this.maxDimension);
  final int? maxDimension;
}

/// Frame rates offered for GIFs made from video (GIFs get big fast).
const kGifFrameRates = [5, 10, 15, 20, 25, 30];

class VideoExportJob {
  const VideoExportJob({
    required this.inputPath,
    required this.outputPath,
    required this.config,
    required this.paletteFrames,
    required this.format,
    this.mp4Resolution = Mp4Resolution.original,
    this.gifSize = const GifSizePerCell(4),
    this.gifFrameRate = 15,
    this.rootToken,
  });

  final String inputPath;

  /// Where the MP4 is written (unused for GIF).
  final String outputPath;

  /// The grid must match the video's aspect ratio (`configFor`).
  final BitmapFilterConfig config;

  /// The same frames the preview built its shared palette from, so the
  /// export uses exactly that palette. Empty when there's no shared palette.
  final List<RgbImage> paletteFrames;
  final VideoFormat format;
  final Mp4Resolution mp4Resolution;
  final GifSize gifSize;
  final int gifFrameRate;

  /// Lets a background isolate talk to the plugin.
  final RootIsolateToken? rootToken;
}

class VideoExportResult {
  const VideoExportResult({
    this.path,
    this.gifBytes,
    required this.frames,
    this.lossyFrames = 0,
    this.audioDropped = false,
  });

  /// The MP4 file (format mp4).
  final String? path;

  /// The encoded GIF (format gif).
  final Uint8List? gifBytes;
  final int frames;
  final int lossyFrames;

  /// The video had sound, but its format can't go into an MP4 unchanged, so
  /// the MP4 was saved silent.
  final bool audioDropped;
}

typedef VideoExporter =
    ExportTask<VideoExportResult> Function(VideoExportJob job, ProgressCallback onProgress);

/// Filter every frame of a video into an MP4 (audio copied through) or an
/// animated GIF (frames sampled down to `gifFrameRate`).
Future<VideoExportResult> exportVideo(
  VideoExportJob job,
  VideoIO io, {
  ProgressCallback? onProgress,
  CancelCheck? isCancelled,
}) async {
  final config = job.config;
  final gif = job.format == VideoFormat.gif;
  final source = await io.open(
    job.inputPath,
    maxDimension: gif ? kMaxAnimationDimension : job.mp4Resolution.maxDimension,
  );
  try {
    final info = source.info;
    final sources = paletteSourceFrames(config, job.paletteFrames.length);
    final palette = sources.isEmpty
        ? null
        : sequencePalette([for (final i in sources) job.paletteFrames[i]], config);
    void checkCancelled() {
      if (isCancelled != null && isCancelled()) throw const ExportCancelled();
    }

    if (!gif) {
      final total = math.max(1, info.estimatedFrameCount);
      final sink = await io.create(
        job.outputPath,
        width: info.width,
        height: info.height,
        frameRate: info.frameRate,
        audioSourcePath: info.hasAudio ? job.inputPath : null,
      );
      var index = 0;
      try {
        while (true) {
          checkCancelled();
          final frame = await source.nextFrame();
          if (frame == null) break;
          final result = applyBitmapFilter(
            RgbImage.fromRgba(frame.width, frame.height, frame.rgba),
            config,
            outputWidth: sink.width,
            outputHeight: sink.height,
            palette: palette,
            seed: frameSeed(config, index),
            isCancelled: isCancelled,
          );
          await sink.addFrame(result.output.toRgba(), frame.pts);
          index++;
          onProgress?.call(math.min(index, total), total);
        }
        await sink.finish();
      } catch (_) {
        await sink.cancel();
        rethrow;
      }
      return VideoExportResult(
        path: job.outputPath,
        frames: index,
        audioDropped: info.hasAudio && !sink.includesAudio,
      );
    }

    final fps = job.gifFrameRate;
    final step = Duration(microseconds: (Duration.microsecondsPerSecond / fps).round());
    final total = math.max(
      1,
      (info.duration.inMicroseconds * fps / Duration.microsecondsPerSecond).ceil(),
    );
    final (w, h) = job.gifSize.outputSize(
      info.width,
      info.height,
      config.gridCols,
      config.gridRows,
    );
    final writer = GifWriter();
    var next = Duration.zero;
    var index = 0;
    while (true) {
      checkCancelled();
      final frame = await source.nextFrame();
      if (frame == null) break;
      final frameIndex = index++;
      if (frame.pts < next) continue; // drop frames above the GIF frame rate
      while (next <= frame.pts) {
        next += step;
      }
      final result = applyBitmapFilter(
        RgbImage.fromRgba(frame.width, frame.height, frame.rgba),
        config,
        outputWidth: w,
        outputHeight: h,
        palette: palette,
        seed: frameSeed(config, frameIndex),
        isCancelled: isCancelled,
      );
      writer.addFrame(result.output, step.inMilliseconds);
      onProgress?.call(math.min(writer.frameCount, total), total);
    }
    return VideoExportResult(
      gifBytes: writer.finish(),
      frames: writer.frameCount,
      lossyFrames: writer.lossyFrames,
    );
  } finally {
    await source.close();
  }
}

/// Run [exportVideo] on a background isolate that talks to the plugin
/// directly. Cancel is cooperative (the worker stops between frames and
/// deletes the partial MP4), but the returned future completes right away.
ExportTask<VideoExportResult> exportVideoInIsolate(
  VideoExportJob job,
  ProgressCallback onProgress,
) {
  final withToken = VideoExportJob(
    inputPath: job.inputPath,
    outputPath: job.outputPath,
    config: job.config,
    paletteFrames: job.paletteFrames,
    format: job.format,
    mp4Resolution: job.mp4Resolution,
    gifSize: job.gifSize,
    gifFrameRate: job.gifFrameRate,
    rootToken: RootIsolateToken.instance,
  );
  final port = ReceivePort();
  final completer = Completer<VideoExportResult>();
  SendPort? control;
  var cancelled = false;

  port.listen((message) {
    switch (message) {
      case ['ready', final SendPort sendPort]:
        control = sendPort;
        if (cancelled) sendPort.send('cancel');
      case ['progress', final int done, final int total]:
        if (!completer.isCompleted) onProgress(done, total);
      case [
        'done',
        final String? path,
        final TransferableTypedData? gif,
        final int frames,
        final int lossy,
        final bool audioDropped,
      ]:
        if (!completer.isCompleted) {
          completer.complete(
            VideoExportResult(
              path: path,
              gifBytes: gif?.materialize().asUint8List(),
              frames: frames,
              lossyFrames: lossy,
              audioDropped: audioDropped,
            ),
          );
        }
        port.close();
      case ['cancelled']:
        port.close();
      case ['error', final String error]:
        if (!completer.isCompleted) completer.completeError(StateError(error));
        port.close();
      case [final Object? error, final Object? _]: // uncaught, from onError
        if (!completer.isCompleted) completer.completeError(StateError('$error'));
        port.close();
    }
  });

  Isolate.spawn(_videoWorker, (port.sendPort, withToken), onError: port.sendPort).catchError((
    Object e,
  ) {
    if (!completer.isCompleted) completer.completeError(e);
    port.close();
    return Isolate.current;
  });

  return ExportTask(completer.future, () {
    if (completer.isCompleted) return;
    cancelled = true;
    control?.send('cancel');
    completer.completeError(const ExportCancelled());
  });
}

Future<void> _videoWorker((SendPort, VideoExportJob) args) async {
  final (port, job) = args;
  final token = job.rootToken;
  if (token != null) BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final control = ReceivePort();
  var cancelled = false;
  control.listen((_) => cancelled = true);
  port.send(['ready', control.sendPort]);
  try {
    final result = await exportVideo(
      job,
      const PluginVideoIO(),
      onProgress: (done, total) => port.send(['progress', done, total]),
      isCancelled: () => cancelled,
    );
    port.send([
      'done',
      result.path,
      result.gifBytes == null ? null : TransferableTypedData.fromList([result.gifBytes!]),
      result.frames,
      result.lossyFrames,
      result.audioDropped,
    ]);
  } on ExportCancelled {
    port.send(['cancelled']);
  } catch (e) {
    port.send(['error', '$e']);
  } finally {
    control.close();
  }
}

/// A fresh temporary path for an MP4 export.
String tempVideoPath(DateTime now) =>
    '${Directory.systemTemp.path}/bitmapper_export_${now.microsecondsSinceEpoch}.mp4';

/// Delete a temporary file, ignoring errors.
void deleteQuietly(String path) {
  try {
    File(path).deleteSync();
  } catch (_) {}
}
