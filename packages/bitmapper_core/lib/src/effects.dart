import 'dart:typed_data';

import 'image.dart';

/// Darken every odd row by `strength` (0 = off, 1 = alternate rows fully
/// black), simulating CRT scanlines.
RgbImage applyScanlines(RgbImage image, double strength) {
  if (strength < 0 || strength > 1) {
    throw ArgumentError.value(strength, 'strength', 'scanlines must be between 0 and 1');
  }
  if (strength == 0) return image;
  final out = Uint8List.fromList(image.data);
  final factor = 1.0 - strength;
  final rowBytes = image.width * 3;
  for (var y = 1; y < image.height; y += 2) {
    final base = y * rowBytes;
    for (var i = base; i < base + rowBytes; i++) {
      out[i] = clampToByte(out[i] * factor);
    }
  }
  return RgbImage(image.width, image.height, out);
}
