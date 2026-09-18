import 'dart:typed_data';

/// Index of the palette entry closest (squared Euclidean distance) to the
/// color `(r, g, b)`. Ties go to the lowest index.
///
/// `palette` is flat RGB, length `K * 3`. This is the single implementation
/// of "closest palette entry" — every other stage calls it.
int nearestIndex(double r, double g, double b, Uint8List palette) {
  var best = 0;
  var bestDist = double.infinity;
  for (var k = 0, i = 0; i < palette.length; k++, i += 3) {
    final dr = r - palette[i];
    final dg = g - palette[i + 1];
    final db = b - palette[i + 2];
    // Summed in the same order as NumPy's `.sum(axis=...)`: (dr² + dg²) + db².
    final d = dr * dr + dg * dg + db * db;
    if (d < bestDist) {
      bestDist = d;
      best = k;
    }
  }
  return best;
}

/// [nearestIndex] for float-valued centers (k-means), with the identical
/// distance and tie rule.
int nearestCenterIndex(double r, double g, double b, Float64List centers) {
  var best = 0;
  var bestDist = double.infinity;
  for (var k = 0, i = 0; i < centers.length; k++, i += 3) {
    final dr = r - centers[i];
    final dg = g - centers[i + 1];
    final db = b - centers[i + 2];
    final d = dr * dr + dg * dg + db * db;
    if (d < bestDist) {
      bestDist = d;
      best = k;
    }
  }
  return best;
}

/// Map every pixel of a flat RGB buffer to its nearest palette color.
/// Returns the quantized bytes.
Uint8List nearestColor(Uint8List rgb, Uint8List palette) {
  final out = Uint8List(rgb.length);
  for (var i = 0; i < rgb.length; i += 3) {
    final k = nearestIndex(
        rgb[i].toDouble(), rgb[i + 1].toDouble(), rgb[i + 2].toDouble(), palette);
    out[i] = palette[k * 3];
    out[i + 1] = palette[k * 3 + 1];
    out[i + 2] = palette[k * 3 + 2];
  }
  return out;
}

/// Like [nearestColor] but for float input (used by ordered/random dither,
/// which perturb pixels before quantizing).
Uint8List nearestColorFloat(Float64List rgb, Uint8List palette) {
  final out = Uint8List(rgb.length);
  for (var i = 0; i < rgb.length; i += 3) {
    final k = nearestIndex(rgb[i], rgb[i + 1], rgb[i + 2], palette);
    out[i] = palette[k * 3];
    out[i + 1] = palette[k * 3 + 1];
    out[i + 2] = palette[k * 3 + 2];
  }
  return out;
}
