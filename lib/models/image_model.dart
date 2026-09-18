import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/foundation.dart';

import '../services/image_codec.dart';
import '../services/image_loader.dart';

/// The loaded photo: the full-size source (for export) and a smaller copy
/// that drives the interactive preview.
class ImageModel extends ChangeNotifier {
  ImageModel(this._loader);

  final ImageLoader _loader;

  String? _name;
  RgbImage? _full;
  RgbImage? _preview;
  bool _loading = false;

  String? get name => _name;
  RgbImage? get full => _full;
  RgbImage? get preview => _preview;
  bool get hasImage => _full != null;
  bool get loading => _loading;

  /// Pick and decode a photo. Returns false if the user cancelled; errors
  /// propagate so the UI can report them, leaving the current image intact.
  Future<bool> load(ImageOrigin origin) async {
    _loading = true;
    notifyListeners();
    try {
      final loaded = await _loader.load(origin);
      if (loaded == null) return false;
      setImage(loaded.name, loaded.image);
      return true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setImage(String name, RgbImage image) {
    _name = name;
    _full = image;
    _preview = makePreviewSource(image);
    notifyListeners();
  }

  void clear() {
    _name = null;
    _full = null;
    _preview = null;
    notifyListeners();
  }
}
