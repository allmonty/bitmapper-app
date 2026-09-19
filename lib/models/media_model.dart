import 'dart:async';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/foundation.dart';

import '../services/gif_io.dart';
import '../services/image_codec.dart';
import '../services/image_loader.dart';
import '../services/video_io.dart';

enum MediaKind { still, animation, video }

/// The loaded photo, animated GIF or video.
///
/// - A still keeps its full-size source (for export) and a smaller copy that
///   drives the interactive preview.
/// - An animation keeps its decoded frames (already capped to preview size),
///   the original GIF bytes (the export worker decodes them itself), and the
///   frame the scrubber is on.
/// - A video keeps an open reader at preview size; frames are fetched as the
///   scrubber moves (latest wins), and the frames a shared palette is built
///   from are sampled and cached on demand.
class MediaModel extends ChangeNotifier {
  MediaModel(this._loader, {VideoIO videoIO = const PluginVideoIO()}) : _videoIO = videoIO;

  final ImageLoader _loader;
  final VideoIO _videoIO;

  MediaKind? _kind;
  String? _name;
  RgbImage? _full;
  RgbImage? _preview;
  DecodedAnimation? _animation;
  Uint8List? _animationBytes;
  int _frame = 0;
  bool _loading = false;

  VideoSource? _video;
  String? _videoPath;
  Object? _videoToken;
  int? _pendingFrame;
  int _shownFrame = 0;
  bool _fetchingFrame = false;
  final Map<int, List<RgbImage>> _samples = {};
  final Set<int> _fetchingSamples = {};
  bool _disposed = false;

  MediaKind? get kind => _kind;
  String? get name => _name;
  bool get hasImage => _kind != null;
  bool get isAnimation => _kind == MediaKind.animation;
  bool get isVideo => _kind == MediaKind.video;

  /// Has more than one frame (GIF or video).
  bool get isSequence => isAnimation || isVideo;
  bool get loading => _loading;

  /// Palette sample frames are being decoded.
  bool get sampling => _fetchingSamples.isNotEmpty;

  /// The full-size still (for export); `null` for animations and videos.
  RgbImage? get full => _full;

  /// What the preview renders: the still's preview copy, or the current
  /// frame of an animation or video.
  RgbImage? get preview => _preview;

  DecodedAnimation? get animation => _animation;
  Uint8List? get animationBytes => _animationBytes;

  VideoInfo? get videoInfo => _video?.info;
  String? get videoPath => _videoPath;

  int get frameCount => switch (_kind) {
    MediaKind.animation => _animation!.frameCount,
    MediaKind.video => _video!.info.estimatedFrameCount.clamp(1, 1 << 30),
    _ => 1,
  };
  int get currentFrame => _frame;

  /// Identifies the loaded sequence (for the preview's palette cache).
  Object? get document => _animation?.frames ?? _videoToken;

  /// Pick a photo, GIF or video (from the library or the camera) and show
  /// it. Returns false if the user cancelled; errors propagate so the UI can
  /// report them, leaving the current media intact.
  Future<bool> load(MediaRequest request) async {
    _loading = true;
    notifyListeners();
    try {
      final loaded = await _loader.load(request);
      if (loaded == null) return false;
      switch (loaded) {
        case LoadedImage(:final name, :final image):
          setImage(name, image);
        case LoadedAnimation(:final name, :final bytes, :final animation):
          setAnimation(name, bytes, animation);
        case LoadedVideo(:final name, :final path):
          await openVideo(name, path);
      }
      return true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setImage(String name, RgbImage image) {
    _reset();
    _kind = MediaKind.still;
    _name = name;
    _full = image;
    _preview = makePreviewSource(image);
    notifyListeners();
  }

  void setAnimation(String name, Uint8List bytes, DecodedAnimation animation) {
    _reset();
    _kind = MediaKind.animation;
    _name = name;
    _animation = animation;
    _animationBytes = bytes;
    _preview = animation.frames.first;
    notifyListeners();
  }

  /// Open the video at `path` (frames scaled to preview size) and show its
  /// first frame. On failure the current media is kept.
  Future<void> openVideo(String name, String path) async {
    final source = await _videoIO.open(path, maxDimension: kPreviewDimension);
    final RgbImage first;
    try {
      first = _toRgb(await source.frameAt(Duration.zero));
    } catch (_) {
      await source.close();
      rethrow;
    }
    _reset();
    _kind = MediaKind.video;
    _name = name;
    _video = source;
    _videoPath = path;
    _videoToken = Object();
    _preview = first;
    notifyListeners();
  }

  /// Show frame `index` (clamped). Videos update the frame number at once
  /// and the picture when the frame has been decoded.
  void setFrame(int index) {
    if (!isSequence) return;
    final i = index.clamp(0, frameCount - 1);
    // A video frame that failed to load can be retried by selecting it again.
    if (i == _frame && (isAnimation || _shownFrame == i)) return;
    _frame = i;
    if (isAnimation) {
      _preview = _animation!.frames[i];
    } else {
      _pendingFrame = i;
      _fetchFrames();
    }
    notifyListeners();
  }

  /// Longest wait for one decoded frame before giving up on it, so a stuck
  /// decode can't block scrubbing forever.
  static const frameTimeout = Duration(seconds: 15);

  Future<void> _fetchFrames() async {
    if (_fetchingFrame) return; // the running fetch picks up _pendingFrame
    _fetchingFrame = true;
    try {
      while (_pendingFrame != null) {
        final index = _pendingFrame!;
        _pendingFrame = null;
        final source = _video;
        if (source == null) return;
        try {
          final frame = await source.frameAt(frameTime(index)).timeout(frameTimeout);
          if (_disposed || !identical(source, _video)) return; // closed or replaced
          if (index == _frame) {
            _preview = _toRgb(frame);
            _shownFrame = index;
            notifyListeners();
          }
        } catch (e) {
          // Keep going: a newer request may already be pending.
          debugPrint('Video frame $index failed to load: $e');
        }
      }
    } finally {
      _fetchingFrame = false;
    }
  }

  /// Presentation time of video frame `index`.
  Duration frameTime(int index) {
    final fps = _video?.info.frameRate ?? 30;
    return Duration(microseconds: (index * Duration.microsecondsPerSecond / fps).round());
  }

  /// `count` frames spread across the video (see `sampleIndices`), at
  /// preview size, for building a shared palette. Returns null while they
  /// are being decoded; listeners are notified when they're ready.
  List<RgbImage>? paletteSamples(int count) {
    final cached = _samples[count];
    if (cached != null || !isVideo) return cached;
    if (_fetchingSamples.add(count)) {
      unawaited(_fetchSamples(count));
      // Called from listeners, so report "sampling" on the next microtask.
      scheduleMicrotask(() {
        if (!_disposed) notifyListeners();
      });
    }
    return null;
  }

  Future<void> _fetchSamples(int count) async {
    final source = _video;
    if (source == null) return;
    try {
      final frames = <RgbImage>[];
      for (final i in sampleIndices(frameCount, count)) {
        frames.add(_toRgb(await source.frameAt(frameTime(i)).timeout(frameTimeout)));
      }
      if (_disposed || !identical(source, _video)) return;
      _fetchingSamples.remove(count);
      _samples[count] = frames;
      notifyListeners();
    } catch (e) {
      debugPrint('Palette sampling failed: $e');
    } finally {
      _fetchingSamples.remove(count);
    }
  }

  void clear() {
    _reset();
    notifyListeners();
  }

  void _reset() {
    unawaited(_video?.close());
    _video = null;
    _videoPath = null;
    _videoToken = null;
    _pendingFrame = null;
    _shownFrame = 0;
    _samples.clear();
    _fetchingSamples.clear();
    _kind = null;
    _name = null;
    _full = null;
    _preview = null;
    _animation = null;
    _animationBytes = null;
    _frame = 0;
  }

  static RgbImage _toRgb(VideoFrame frame) =>
      RgbImage.fromRgba(frame.width, frame.height, frame.rgba);

  @override
  void dispose() {
    _disposed = true;
    unawaited(_video?.close());
    super.dispose();
  }
}
