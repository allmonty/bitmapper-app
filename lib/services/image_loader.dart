import 'dart:isolate';
import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:image_picker/image_picker.dart';

import 'gif_io.dart';
import 'image_codec.dart';

enum ImageOrigin { gallery, camera }

/// A picked file, decoded.
sealed class LoadedMedia {
  const LoadedMedia({required this.name});
  final String name;
}

/// A still photo.
class LoadedImage extends LoadedMedia {
  const LoadedImage({required super.name, required this.image});
  final RgbImage image;
}

/// An animated GIF. `bytes` is the original file, so the export worker can
/// decode it again instead of receiving every frame.
class LoadedAnimation extends LoadedMedia {
  const LoadedAnimation({required super.name, required this.bytes, required this.animation});
  final Uint8List bytes;
  final DecodedAnimation animation;
}

/// Picks and decodes a photo or GIF. Returns `null` when the user cancels.
abstract class ImageLoader {
  Future<LoadedMedia?> load(ImageOrigin origin);
}

/// Picks with `image_picker` and decodes with the platform codec.
class PickerImageLoader implements ImageLoader {
  PickerImageLoader({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<LoadedMedia?> load(ImageOrigin origin) async {
    // No maxWidth/maxHeight: resizing in the picker would flatten animated
    // GIFs. Stills are capped while decoding instead.
    final file = await _picker.pickImage(
      source: origin == ImageOrigin.camera ? ImageSource.camera : ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return decodeMedia(file.name, await file.readAsBytes());
  }
}

/// Decode picked bytes: a GIF with more than one frame becomes an
/// animation, anything else a still (capped at [kMaxSourceDimension]).
Future<LoadedMedia> decodeMedia(String name, Uint8List bytes) async {
  if (isGif(bytes)) {
    final animation = await Isolate.run(() => decodeGif(bytes));
    if (animation != null && animation.frameCount > 1) {
      return LoadedAnimation(name: name, bytes: bytes, animation: animation);
    }
  }
  return LoadedImage(name: name, image: await decodeToRgb(bytes));
}
