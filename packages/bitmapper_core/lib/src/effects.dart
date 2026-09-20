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
  // A byte can only take 256 values, so precompute clampToByte(v * factor)
  // once instead of paying a double multiply and a function call per byte
  // in the loop below (measured as the pipeline's single most expensive
  // stage on a full-size export before this change — see
  // tool/benchmark_stages.dart and docs/plans/gpu-performance.md).
  final lut = Uint8List(256);
  for (var v = 0; v < 256; v++) {
    lut[v] = clampToByte(v * factor);
  }
  final rowBytes = image.width * 3;
  for (var y = 1; y < image.height; y += 2) {
    final base = y * rowBytes;
    for (var i = base; i < base + rowBytes; i++) {
      out[i] = lut[out[i]];
    }
  }
  return RgbImage(image.width, image.height, out);
}
