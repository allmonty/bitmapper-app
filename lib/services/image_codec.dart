import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:image/image.dart' as img;

/// Longest edge kept when loading a photo; bigger images are scaled down on
/// decode so full-size export stays within memory on phones.
const kMaxSourceDimension = 4096;

/// Longest edge of the interactive preview.
const kPreviewDimension = 1024;

/// Biggest image decoded in pure Dart (about 256 MB of pixels while
/// decoding); larger ones use the platform decoder, which can downscale
/// while decoding.
const kMaxDartDecodePixels = 64 * 1000 * 1000;

/// Decode JPEG/PNG/WebP/etc. bytes to an upright RGB image, scaled down so
/// neither edge exceeds `maxDimension`.
///
/// Decoding runs in pure Dart on a background isolate (rotation from EXIF
/// applied), so the result doesn't depend on the device's GPU image
/// pipeline: on some Android devices, images decoded by the engine came
/// back partly smeared toward the right and bottom. Formats the pure-Dart
/// decoders don't know (e.g. HEIC) and very large photos fall back to the
/// platform codec.
Future<RgbImage> decodeToRgb(Uint8List bytes, {int maxDimension = kMaxSourceDimension}) async {
  final decoded = await Isolate.run(() => decodeWithDart(bytes, maxDimension: maxDimension));
  return decoded ?? decodeWithPlatform(bytes, maxDimension: maxDimension);
}

/// Pure-Dart decode (see [decodeToRgb]); null when the format isn't
/// supported, the data is broken, or the image exceeds
/// [kMaxDartDecodePixels].
RgbImage? decodeWithDart(Uint8List bytes, {int maxDimension = kMaxSourceDimension}) {
  final decoder = img.findDecoderForData(bytes);
  if (decoder == null) return null;
  final info = decoder.startDecode(bytes);
  if (info == null || info.width * info.height > kMaxDartDecodePixels) return null;
  final img.Image? decoded;
  try {
    decoded = decoder.decode(bytes, frame: 0);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;
  final rgb = img
      .bakeOrientation(decoded)
      .convert(format: img.Format.uint8, numChannels: 3, withPalette: false);
  final image = RgbImage(rgb.width, rgb.height, Uint8List.fromList(rgb.toUint8List()));
  final (w, h) = fitWithin(image.width, image.height, maxDimension);
  return w == image.width && h == image.height ? image : downsample(image, w, h);
}

/// Decode with the platform codec (which honours EXIF orientation), scaling
/// down so neither edge exceeds `maxDimension`.
Future<RgbImage> decodeWithPlatform(
  Uint8List bytes, {
  int maxDimension = kMaxSourceDimension,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final (w, h) = fitWithin(descriptor.width, descriptor.height, maxDimension);
  // Only ask the codec to resize when needed.
  final resize = w != descriptor.width || h != descriptor.height;
  final codec = await descriptor.instantiateCodec(
    targetWidth: resize ? w : null,
    targetHeight: resize ? h : null,
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw StateError('could not read decoded pixels');
    return RgbImage.fromRgba(image.width, image.height, data.buffer.asUint8List());
  } finally {
    image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}

/// Scale `(width, height)` down (never up) so the longest edge is at most
/// `maxDimension`, keeping the aspect ratio.
(int, int) fitWithin(int width, int height, int maxDimension) {
  final longest = width > height ? width : height;
  if (longest <= maxDimension) return (width, height);
  final scale = maxDimension / longest;
  final w = (width * scale).round();
  final h = (height * scale).round();
  return (w < 1 ? 1 : w, h < 1 ? 1 : h);
}

/// A smaller copy for interactive previews (box-filtered with the engine's
/// own downsample), or `source` itself when already small enough.
RgbImage makePreviewSource(RgbImage source, {int maxDimension = kPreviewDimension}) {
  final (w, h) = fitWithin(source.width, source.height, maxDimension);
  if (w == source.width && h == source.height) return source;
  return downsample(source, w, h);
}

/// Encode as PNG (pure Dart, safe to run in an isolate).
Uint8List encodePng(RgbImage image) {
  final out = img.Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: image.data.buffer,
    bytesOffset: image.data.offsetInBytes,
    numChannels: 3,
  );
  return img.encodePng(out);
}

Future<Uint8List> encodePngInBackground(RgbImage image) => Isolate.run(() => encodePng(image));
