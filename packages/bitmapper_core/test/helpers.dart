import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';

/// Image from nested `[row][col] = [r, g, b]` lists.
RgbImage imageFromRows(List<List<List<int>>> rows) {
  final h = rows.length, w = rows.first.length;
  final data = Uint8List(w * h * 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      data.setRange((y * w + x) * 3, (y * w + x) * 3 + 3, rows[y][x]);
    }
  }
  return RgbImage(w, h, data);
}

RgbImage solidImage(int w, int h, List<int> rgb) {
  final data = Uint8List(w * h * 3);
  for (var i = 0; i < data.length; i += 3) {
    data.setRange(i, i + 3, rgb);
  }
  return RgbImage(w, h, data);
}

/// Deterministic pseudo-random image (not tied to any reference PRNG).
RgbImage randomImage(int w, int h, {int seed = 0}) {
  final rng = XorShift128Plus(seed);
  final data = Uint8List(w * h * 3);
  for (var i = 0; i < data.length; i++) {
    data[i] = rng.nextInt64() & 0xFF;
  }
  return RgbImage(w, h, data);
}

/// 16x16 horizontal gray ramp, like the Python `gradient_image` fixture.
RgbImage gradientImage() {
  final data = Uint8List(16 * 16 * 3);
  for (var y = 0; y < 16; y++) {
    for (var x = 0; x < 16; x++) {
      final v = (x * 255 / 15).toInt();
      data.setRange((y * 16 + x) * 3, (y * 16 + x) * 3 + 3, [v, v, v]);
    }
  }
  return RgbImage(16, 16, data);
}

RgbImage checkerboardImage() => imageFromRows([
  for (var y = 0; y < 8; y++)
    [
      for (var x = 0; x < 8; x++) (x + y).isEven ? [0, 0, 0] : [255, 255, 255],
    ],
]);

bool onlyUsesPalette(RgbImage image, Uint8List palette) =>
    colorSet(palette).containsAll(colorSet(image.data));
