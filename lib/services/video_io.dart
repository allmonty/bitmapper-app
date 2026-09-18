import 'dart:typed_data';

import 'package:video_frames/video_frames.dart';

export 'package:video_frames/video_frames.dart' show VideoFrame, VideoInfo;

/// An open video being read.
abstract class VideoSource {
  VideoInfo get info;
  Future<VideoFrame?> nextFrame();
  Future<VideoFrame> frameAt(Duration time);
  Future<void> close();
}

/// An MP4 being written.
abstract class VideoSink {
  /// Encoded size (even numbers).
  int get width;
  int get height;
  Future<void> addFrame(Uint8List rgba, Duration pts);
  Future<void> finish();
  Future<void> cancel();
}

/// Opens videos for reading and writing. The app uses [PluginVideoIO];
/// tests swap in synthetic video.
abstract class VideoIO {
  Future<VideoSource> open(String path, {int? maxDimension});
  Future<VideoSink> create(
    String path, {
    required int width,
    required int height,
    required double frameRate,
    String? audioSourcePath,
  });
}

/// [VideoIO] backed by the `video_frames` plugin.
class PluginVideoIO implements VideoIO {
  const PluginVideoIO();

  @override
  Future<VideoSource> open(String path, {int? maxDimension}) async =>
      _PluginSource(await VideoReader.open(path, maxDimension: maxDimension));

  @override
  Future<VideoSink> create(
    String path, {
    required int width,
    required int height,
    required double frameRate,
    String? audioSourcePath,
  }) async => _PluginSink(
    await VideoWriter.create(
      path,
      width: width,
      height: height,
      frameRate: frameRate,
      audioSourcePath: audioSourcePath,
    ),
  );
}

class _PluginSource implements VideoSource {
  _PluginSource(this._reader);
  final VideoReader _reader;

  @override
  VideoInfo get info => _reader.info;
  @override
  Future<VideoFrame?> nextFrame() => _reader.nextFrame();
  @override
  Future<VideoFrame> frameAt(Duration time) => _reader.frameAt(time);
  @override
  Future<void> close() => _reader.close();
}

class _PluginSink implements VideoSink {
  _PluginSink(this._writer);
  final VideoWriter _writer;

  @override
  int get width => _writer.width;
  @override
  int get height => _writer.height;
  @override
  Future<void> addFrame(Uint8List rgba, Duration pts) => _writer.addFrame(rgba, pts);
  @override
  Future<void> finish() => _writer.finish();
  @override
  Future<void> cancel() => _writer.cancel();
}
