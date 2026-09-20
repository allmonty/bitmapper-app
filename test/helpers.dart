import 'dart:typed_data';

import 'package:bitmapper/main.dart';
import 'package:bitmapper/repositories/preset_repository.dart';
import 'package:bitmapper/services/animation_exporter.dart';
import 'package:bitmapper/services/app_services.dart';
import 'package:bitmapper/services/export_notifier.dart';
import 'package:bitmapper/services/filter_controller.dart';
import 'package:bitmapper/services/image_codec.dart';
import 'package:bitmapper/services/image_loader.dart';
import 'package:bitmapper/services/image_saver.dart';
import 'package:bitmapper/services/video_exporter.dart';
import 'package:bitmapper/services/video_io.dart';
import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A `width x height` image with a diagonal color gradient.
RgbImage gradient(int width, int height) {
  final data = Uint8List(width * height * 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 3;
      data[i] = (x * 255) ~/ (width - 1);
      data[i + 1] = (y * 255) ~/ (height - 1);
      data[i + 2] = ((x + y) * 127) ~/ (width + height);
    }
  }
  return RgbImage(width, height, data);
}

class FakeImageLoader implements ImageLoader {
  FakeImageLoader({this.result, this.error});

  LoadedMedia? result;
  Object? error;
  final List<MediaRequest> calls = [];

  @override
  Future<LoadedMedia?> load(MediaRequest request) async {
    calls.add(request);
    if (error != null) throw error!;
    return result;
  }
}

class FakeImageSaver implements ImageSaver {
  final List<(Uint8List, String, String)> saved = [];
  Object? error;

  @override
  Future<String?> save(Uint8List bytes, String fileName, {String mimeType = 'image/png'}) async {
    if (error != null) throw error!;
    saved.add((bytes, fileName, mimeType));
    return '/fake/$fileName';
  }

  final List<(String, String, String)> savedFiles = [];

  @override
  Future<String?> saveFile(String path, String fileName, {required String mimeType}) async {
    if (error != null) throw error!;
    savedFiles.add((path, fileName, mimeType));
    return '/fake/$fileName';
  }
}

/// Runs [exportGif] on the test isolate after a microtask turn, so
/// progress updates and cancellation behave like the isolate version.
ExportTask<GifExportResult> fakeGifExporter(GifExportJob job, ProgressCallback onProgress) {
  var cancelled = false;
  final result = Future(() async {
    await Future<void>.delayed(Duration.zero);
    if (cancelled) throw const ExportCancelled();
    return exportGif(job, onProgress: onProgress, isCancelled: () => cancelled);
  });
  return ExportTask(result, () => cancelled = true);
}

/// Runs the real pipeline on the test's own isolate (Isolate.run doesn't
/// complete under the widget tester's fake async).
Future<FilterResult> syncRunner(FilterJob job) async => applyBitmapFilter(
  job.source,
  job.config,
  outputWidth: job.outputWidth,
  outputHeight: job.outputHeight,
);

/// Records every call instead of touching a platform channel. `calls` is
/// the event sequence (`'start'`, `'progress'`, `'succeed'`, `'fail'`,
/// `'cancel'`), so tests can assert on both ordering and the final state.
class FakeExportNotifier implements ExportNotifier {
  final calls = <String>[];
  String? lastTitle;
  final progressCalls = <(int, int)>[];
  String? lastMessage;

  @override
  Future<void> start(String title) async {
    calls.add('start');
    lastTitle = title;
  }

  @override
  Future<void> progress(int done, int total) async {
    calls.add('progress');
    progressCalls.add((done, total));
  }

  @override
  Future<void> succeed(String message) async {
    calls.add('succeed');
    lastMessage = message;
  }

  @override
  Future<void> fail(String message) async {
    calls.add('fail');
    lastMessage = message;
  }

  @override
  Future<void> cancel() async => calls.add('cancel');
}

class TestApp {
  TestApp({LoadedMedia? image})
    : loader = FakeImageLoader(result: image),
      saver = FakeImageSaver(),
      repository = InMemoryPresetRepository();

  final FakeImageLoader loader;
  final FakeImageSaver saver;
  final InMemoryPresetRepository repository;
  final FakeVideoIO videoIO = FakeVideoIO();
  final FakeExportNotifier notifier = FakeExportNotifier();

  AppServices get services => AppServices(
    imageLoader: loader,
    imageSaver: saver,
    presetRepository: repository,
    filterRunner: syncRunner,
    pngEncoder: (image) async => encodePng(image),
    gifExporter: fakeGifExporter,
    videoIO: videoIO,
    videoExporter: (job, onProgress) => fakeVideoExporter(job, onProgress, videoIO),
    clock: () => DateTime.fromMillisecondsSinceEpoch(1234),
    exportNotifier: notifier,
  );

  Widget build({Locale locale = const Locale('en')}) =>
      BitmapperApp(services: services, locale: locale);
}

/// A phone-sized portrait viewport.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// An animated GIF with `n` frames of a shifting gradient, built with
/// package:image.
Uint8List makeGif({int n = 3, int width = 40, int height = 30, int loopCount = 0}) {
  final encoder = img.GifEncoder(repeat: loopCount);
  for (var f = 0; f < n; f++) {
    final frame = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        frame.setPixelRgb(x, y, (x * 6 + f * 40) % 256, y * 8 % 256, (f * 90) % 256);
      }
    }
    encoder.addFrame(frame, duration: 5 + f * 5); // 50, 100, 150 ms
  }
  return encoder.finish()!;
}

/// Synthetic video: `frameCount` frames at `frameRate`, each a gradient
/// whose red channel drifts over time.
class FakeVideoIO implements VideoIO {
  FakeVideoIO({
    this.width = 64,
    this.height = 48,
    this.frameCount = 30,
    this.frameRate = 30,
    this.hasAudio = true,
    this.audioCompatible = true,
  });

  final int width;
  final int height;
  final int frameCount;
  final double frameRate;
  final bool hasAudio;
  bool audioCompatible;

  final opened = <(String, int?)>[];
  final sinks = <FakeVideoSink>[];
  final sources = <FakeVideoSource>[];
  Object? openError;

  /// Runs before every `frameAt`; can delay it (return a future) or throw.
  Future<void> Function(Duration time)? beforeFrameAt;

  @override
  Future<VideoSource> open(String path, {int? maxDimension}) async {
    if (openError != null) throw openError!;
    opened.add((path, maxDimension));
    var (w, h) = (width, height);
    if (maxDimension != null && (w > maxDimension || h > maxDimension)) {
      final scale = maxDimension / (w > h ? w : h);
      (w, h) = ((w * scale).round(), (h * scale).round());
    }
    final source = FakeVideoSource(this, w, h);
    sources.add(source);
    return source;
  }

  @override
  Future<VideoSink> create(
    String path, {
    required int width,
    required int height,
    required double frameRate,
    String? audioSourcePath,
  }) async {
    final sink = FakeVideoSink(
      path,
      width & ~1,
      height & ~1,
      audioSourcePath,
      includesAudio: audioSourcePath != null && hasAudio && audioCompatible,
    );
    sinks.add(sink);
    return sink;
  }

  Uint8List frameRgba(int w, int h, int index) {
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        out[o] = (x * 255 ~/ w + index * 5) % 256;
        out[o + 1] = y * 255 ~/ h;
        out[o + 2] = 90;
        out[o + 3] = 255;
      }
    }
    return out;
  }
}

class FakeVideoSource implements VideoSource {
  FakeVideoSource(this.io, this.width, this.height);
  final FakeVideoIO io;
  final int width;
  final int height;
  int _next = 0;
  bool closed = false;
  final frameAtCalls = <Duration>[];

  Duration _pts(int i) => Duration(microseconds: (i * 1000000 / io.frameRate).round());

  @override
  VideoInfo get info => VideoInfo(
    width: width,
    height: height,
    duration: _pts(io.frameCount),
    frameRate: io.frameRate,
    rotationDegrees: 0,
    hasAudio: io.hasAudio,
    audioCompatible: io.hasAudio && io.audioCompatible,
  );

  @override
  Future<VideoFrame?> nextFrame() async {
    if (_next >= io.frameCount) return null;
    final i = _next++;
    return VideoFrame(
      pts: _pts(i),
      width: width,
      height: height,
      rgba: io.frameRgba(width, height, i),
    );
  }

  @override
  Future<VideoFrame> frameAt(Duration time) async {
    frameAtCalls.add(time);
    await io.beforeFrameAt?.call(time);
    final i = (time.inMicroseconds * io.frameRate / 1000000).round().clamp(0, io.frameCount - 1);
    return VideoFrame(
      pts: _pts(i),
      width: width,
      height: height,
      rgba: io.frameRgba(width, height, i),
    );
  }

  @override
  Future<void> close() async => closed = true;
}

class FakeVideoSink implements VideoSink {
  FakeVideoSink(
    this.path,
    this.width,
    this.height,
    this.audioSourcePath, {
    this.includesAudio = false,
  });
  final String path;
  @override
  final int width;
  @override
  final int height;
  final String? audioSourcePath;
  @override
  final bool includesAudio;
  final frames = <(Uint8List, Duration)>[];
  bool finished = false;
  bool cancelled = false;

  @override
  Future<void> addFrame(Uint8List rgba, Duration pts) async {
    if (rgba.length != width * height * 4) throw ArgumentError('bad frame size');
    frames.add((rgba, pts));
  }

  @override
  Future<void> finish() async => finished = true;

  @override
  Future<void> cancel() async => cancelled = true;
}

/// Runs [exportVideo] with [FakeVideoIO] on the test isolate.
ExportTask<VideoExportResult> fakeVideoExporter(
  VideoExportJob job,
  ProgressCallback onProgress,
  VideoIO io,
) {
  var cancelled = false;
  final result = Future(() async {
    await Future<void>.delayed(Duration.zero);
    return exportVideo(job, io, onProgress: onProgress, isCancelled: () => cancelled);
  });
  return ExportTask(result, () => cancelled = true);
}
