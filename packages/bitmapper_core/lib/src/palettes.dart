import 'dart:typed_data';

import 'palettes_data.dart';

/// Names of the fixed palettes, sorted.
List<String> listPalettes() => kPaletteData.keys.toList()..sort();

/// A copy of the named fixed palette as flat RGB bytes.
Uint8List getPalette(String name) {
  final data = kPaletteData[name];
  if (data == null) {
    throw ArgumentError(
        'unknown fixed palette "$name", available: ${listPalettes()}');
  }
  return Uint8List.fromList(data);
}

/// Number of colors in a flat RGB palette.
int paletteLength(Uint8List palette) => palette.length ~/ 3;

/// NumPy's `round()`: round half to even (banker's rounding). Dart's
/// `round()` rounds half away from zero, which differs at exact .5 values.
int roundHalfEven(double v) {
  final floor = v.floorToDouble();
  final diff = v - floor;
  if (diff > 0.5) return floor.toInt() + 1;
  if (diff < 0.5) return floor.toInt();
  final f = floor.toInt();
  return f.isEven ? f : f + 1;
}

/// Evenly-spaced indices as `np.linspace(0, length - 1, n).round()`.
List<int> linspaceIndices(int length, int n) {
  if (n == 1) return [0];
  final stop = (length - 1).toDouble();
  final step = stop / (n - 1);
  return List<int>.generate(
      n, (i) => i == n - 1 ? length - 1 : roundHalfEven(i * step));
}

/// Pick `nColors` evenly-spaced entries from `palette` (keeping the first and
/// last). Returns a copy unchanged when it already has <= `nColors` entries.
Uint8List subsample(Uint8List palette, int nColors) {
  if (nColors < 1) {
    throw ArgumentError.value(nColors, 'nColors', 'must be >= 1');
  }
  final length = paletteLength(palette);
  if (nColors >= length) return Uint8List.fromList(palette);
  final out = Uint8List(nColors * 3);
  final idx = linspaceIndices(length, nColors);
  for (var i = 0; i < nColors; i++) {
    out.setRange(i * 3, i * 3 + 3, palette, idx[i] * 3);
  }
  return out;
}
