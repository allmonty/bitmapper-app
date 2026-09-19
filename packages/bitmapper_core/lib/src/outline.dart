import 'dart:typed_data';

import 'image.dart';

/// Rec. 601 luma as `(r * 0.299 + g * 0.587) + b * 0.114`, the same order as
/// the Python reference, so outline decisions match exactly.
double luminance(int r, int g, int b) => r * 0.299 + g * 0.587 + b * 0.114;

/// Brightness jump that counts as an edge: 128 at strength 0+, down to 16
/// at strength 1 (stronger = more edges outlined).
double outlineThreshold(double strength) => 128.0 - 112.0 * strength;

/// Index of the palette entry with the lowest luminance (first on ties).
int darkestColorIndex(Uint8List palette) {
  var best = 0;
  var bestLum = double.infinity;
  for (var k = 0, i = 0; i < palette.length; k++, i += 3) {
    final l = luminance(palette[i], palette[i + 1], palette[i + 2]);
    if (l < bestLum) {
      bestLum = l;
      best = k;
    }
  }
  return best;
}

/// Sprite-style ink outlines on the quantized `grid`: a cell becomes ink
/// (the palette's darkest color) when one of its 4 neighbours is brighter
/// by more than [outlineThreshold]. The line lands on the dark side of each
/// strong edge, one cell thick, and the output stays within the palette.
/// `strength` 0 is off; 1 outlines the faintest edges.
RgbImage applyOutline(RgbImage grid, Uint8List palette, double strength) {
  if (strength < 0 || strength > 1) {
    throw ArgumentError.value(strength, 'strength', 'outline must be between 0 and 1');
  }
  if (strength == 0 || grid.pixelCount == 0) return grid;
  final w = grid.width, h = grid.height, src = grid.data;
  final lum = Float64List(w * h);
  for (var p = 0; p < lum.length; p++) {
    lum[p] = luminance(src[p * 3], src[p * 3 + 1], src[p * 3 + 2]);
  }
  final threshold = outlineThreshold(strength);
  final ink = darkestColorIndex(palette) * 3;
  final out = Uint8List.fromList(src);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = y * w + x;
      final l = lum[p];
      final edge =
          (x + 1 < w && lum[p + 1] - l > threshold) ||
          (x > 0 && lum[p - 1] - l > threshold) ||
          (y + 1 < h && lum[p + w] - l > threshold) ||
          (y > 0 && lum[p - w] - l > threshold);
      if (edge) out.setRange(p * 3, p * 3 + 3, palette, ink);
    }
  }
  return RgbImage(w, h, out);
}
