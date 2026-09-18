import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/foundation.dart';

import '../services/gif_io.dart';
import '../services/image_codec.dart';
import '../services/image_loader.dart';

enum MediaKind { still, animation }

/// The loaded photo or animation.
///
/// - A still keeps its full-size source (for export) and a smaller copy that
///   drives the interactive preview.
/// - An animation keeps its decoded frames (already capped to preview size),
///   the original GIF bytes (the export worker decodes them itself), and the
///   frame the scrubber is on.
class MediaModel extends ChangeNotifier {
  MediaModel(this._loader);

  final ImageLoader _loader;

  MediaKind? _kind;
  String? _name;
  RgbImage? _full;
  RgbImage? _preview;
  DecodedAnimation? _animation;
  Uint8List? _animationBytes;
  int _frame = 0;
  bool _loading = false;

  MediaKind? get kind => _kind;
  String? get name => _name;
  bool get hasImage => _kind != null;
  bool get isAnimation => _kind == MediaKind.animation;
  bool get loading => _loading;

  /// The full-size still (for export); `null` for animations.
  RgbImage? get full => _full;

  /// What the preview renders: the still's preview copy, or the current
  /// animation frame.
  RgbImage? get preview => _preview;

  DecodedAnimation? get animation => _animation;
  Uint8List? get animationBytes => _animationBytes;
  int get frameCount => _animation?.frameCount ?? 1;
  int get currentFrame => _frame;

  /// Pick and decode a photo or GIF. Returns false if the user cancelled;
  /// errors propagate so the UI can report them, leaving the current media
  /// intact.
  Future<bool> load(ImageOrigin origin) async {
    _loading = true;
    notifyListeners();
    try {
      final loaded = await _loader.load(origin);
      if (loaded == null) return false;
      switch (loaded) {
        case LoadedImage(:final name, :final image):
          setImage(name, image);
        case LoadedAnimation(:final name, :final bytes, :final animation):
          setAnimation(name, bytes, animation);
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

  /// Show frame `index` (clamped) of an animation.
  void setFrame(int index) {
    final animation = _animation;
    if (animation == null) return;
    final i = index.clamp(0, animation.frameCount - 1);
    if (i == _frame) return;
    _frame = i;
    _preview = animation.frames[i];
    notifyListeners();
  }

  void clear() {
    _reset();
    notifyListeners();
  }

  void _reset() {
    _kind = null;
    _name = null;
    _full = null;
    _preview = null;
    _animation = null;
    _animationBytes = null;
    _frame = 0;
  }
}
