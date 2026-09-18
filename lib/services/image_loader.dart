import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:image_picker/image_picker.dart';

import 'image_codec.dart';

enum ImageOrigin { gallery, camera }

class LoadedImage {
  const LoadedImage({required this.name, required this.image});
  final String name;
  final RgbImage image;
}

/// Picks and decodes a photo. Returns `null` when the user cancels.
abstract class ImageLoader {
  Future<LoadedImage?> load(ImageOrigin origin);
}

/// Picks with `image_picker` and decodes with the platform codec.
class PickerImageLoader implements ImageLoader {
  PickerImageLoader({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<LoadedImage?> load(ImageOrigin origin) async {
    final file = await _picker.pickImage(
      source: origin == ImageOrigin.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: kMaxSourceDimension.toDouble(),
      maxHeight: kMaxSourceDimension.toDouble(),
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final image = await decodeToRgb(await file.readAsBytes());
    return LoadedImage(name: file.name, image: image);
  }
}
