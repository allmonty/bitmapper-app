import 'dart:isolate';
import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:image_picker/image_picker.dart';

import 'gif_io.dart';
import 'image_codec.dart';

/// Where new media comes from.
enum MediaRequest {
  /// A photo, GIF or video from the library (one picker for all of them).
  library,

  /// Take a photo with the camera.
  cameraPhoto,

  /// Record a video with the camera.
  cameraVideo,
}

/// A picked file, ready to show.
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

/// A video file. Not decoded here: it's read on demand, frame by frame.
class LoadedVideo extends LoadedMedia {
  const LoadedVideo({required super.name, required this.path});
  final String path;
}

/// Picks media and decodes images. Returns `null` when the user cancels.
abstract class ImageLoader {
  Future<LoadedMedia?> load(MediaRequest request);
}

/// Picks with `image_picker` and decodes images with the platform codec.
class PickerImageLoader implements ImageLoader {
  PickerImageLoader({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<LoadedMedia?> load(MediaRequest request) async {
    // No maxWidth/maxHeight: resizing in the picker would flatten animated
    // GIFs. Stills are capped while decoding instead.
    final XFile? file = switch (request) {
      MediaRequest.library => await _picker.pickMedia(requestFullMetadata: false),
      MediaRequest.cameraPhoto => await _picker.pickImage(
        source: ImageSource.camera,
        requestFullMetadata: false,
      ),
      MediaRequest.cameraVideo => await _picker.pickVideo(source: ImageSource.camera),
    };
    if (file == null) return null;
    if (request == MediaRequest.cameraVideo || isVideoFile(file.name, file.mimeType)) {
      return LoadedVideo(name: file.name, path: file.path);
    }
    try {
      return await decodeMedia(file.name, await file.readAsBytes());
    } catch (_) {
      // Not an image the platform can decode; maybe a video with an unusual
      // extension. If it isn't, opening it as a video reports the error.
      return LoadedVideo(name: file.name, path: file.path);
    }
  }
}

const _videoExtensions = {
  'mp4',
  'm4v',
  'mov',
  'qt',
  '3gp',
  '3g2',
  'mkv',
  'webm',
  'avi',
  'mpg',
  'mpeg',
  'ts',
  'mts',
};

/// Whether a picked file is a video, by MIME type or file extension.
bool isVideoFile(String name, [String? mimeType]) {
  if (mimeType != null && mimeType.startsWith('video/')) return true;
  final dot = name.lastIndexOf('.');
  return dot >= 0 && _videoExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// Decode picked image bytes: a GIF with more than one frame becomes an
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
