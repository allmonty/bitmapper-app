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

/// Decode PNG/JPEG/etc. bytes with the platform codec (which honours EXIF
/// orientation), scaling down so neither edge exceeds `maxDimension`.
Future<RgbImage> decodeToRgb(Uint8List bytes, {int maxDimension = kMaxSourceDimension}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final (w, h) = fitWithin(descriptor.width, descriptor.height, maxDimension);
  final codec = await descriptor.instantiateCodec(targetWidth: w, targetHeight: h);
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

/// Encode as an uncompressed 24-bit BMP. Cheap enough to do per preview
/// frame, and `Image.memory` can display it directly.
Uint8List encodeBmp(RgbImage image) {
  final w = image.width, h = image.height;
  final rowSize = (w * 3 + 3) & ~3;
  final pixelBytes = rowSize * h;
  final out = Uint8List(54 + pixelBytes);
  final bd = ByteData.view(out.buffer);
  out[0] = 0x42; // 'B'
  out[1] = 0x4D; // 'M'
  bd.setUint32(2, out.length, Endian.little);
  bd.setUint32(10, 54, Endian.little); // pixel data offset
  bd.setUint32(14, 40, Endian.little); // BITMAPINFOHEADER size
  bd.setInt32(18, w, Endian.little);
  bd.setInt32(22, -h, Endian.little); // negative height: top-down rows
  bd.setUint16(26, 1, Endian.little); // planes
  bd.setUint16(28, 24, Endian.little); // bits per pixel
  bd.setUint32(34, pixelBytes, Endian.little);
  final src = image.data;
  for (var y = 0; y < h; y++) {
    var o = 54 + y * rowSize;
    var i = y * w * 3;
    for (var x = 0; x < w; x++, i += 3, o += 3) {
      out[o] = src[i + 2]; // BGR
      out[o + 1] = src[i + 1];
      out[o + 2] = src[i];
    }
  }
  return out;
}
