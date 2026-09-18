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
  final search = PaletteSearch(palette);
  final out = Uint8List(rgb.length);
  for (var i = 0; i < rgb.length; i += 3) {
    final k = search.nearest(rgb[i].toDouble(), rgb[i + 1].toDouble(), rgb[i + 2].toDouble());
    out[i] = palette[k * 3];
    out[i + 1] = palette[k * 3 + 1];
    out[i + 2] = palette[k * 3 + 2];
  }
  return out;
}

/// Like [nearestColor] but for float input (used by ordered/random dither,
/// which perturb pixels before quantizing).
Uint8List nearestColorFloat(Float64List rgb, Uint8List palette) {
  final search = PaletteSearch(palette);
  final out = Uint8List(rgb.length);
  for (var i = 0; i < rgb.length; i += 3) {
    final k = search.nearest(rgb[i], rgb[i + 1], rgb[i + 2]);
    out[i] = palette[k * 3];
    out[i + 1] = palette[k * 3 + 1];
    out[i + 2] = palette[k * 3 + 2];
  }
  return out;
}

/// Exact nearest-color search for repeated lookups against one palette.
///
/// Returns exactly what [nearestIndex] would (same distance, same
/// lowest-index tie rule) but is sub-linear for big palettes: entries are
/// sorted by red, the search walks outward from the query's red value, and
/// a side stops once its red gap alone exceeds the best distance so far.
/// Small palettes use the plain linear scan.
class PaletteSearch {
  PaletteSearch(Uint8List palette)
    : this._(Float64List.fromList([for (final v in palette) v.toDouble()]));

  /// For float-valued centers (k-means).
  PaletteSearch.floats(Float64List centers) : this._(centers);

  PaletteSearch._(this._flat) : length = _flat.length ~/ 3 {
    if (length > _linearLimit) _buildIndex();
  }

  /// Below this many entries the linear scan is faster than the index.
  static const _linearLimit = 24;

  final Float64List _flat;
  final int length;
  late final Float64List _r, _g, _b;
  late final Int32List _idx;

  void _buildIndex() {
    final order = List<int>.generate(length, (i) => i)
      ..sort((a, b) {
        final c = _flat[a * 3].compareTo(_flat[b * 3]);
        return c != 0 ? c : a.compareTo(b);
      });
    _r = Float64List(length);
    _g = Float64List(length);
    _b = Float64List(length);
    _idx = Int32List(length);
    for (var i = 0; i < length; i++) {
      final k = order[i];
      _r[i] = _flat[k * 3];
      _g[i] = _flat[k * 3 + 1];
      _b[i] = _flat[k * 3 + 2];
      _idx[i] = k;
    }
  }

  int nearest(double r, double g, double b) {
    if (length <= _linearLimit) return nearestCenterIndex(r, g, b, _flat);

    // Start at the first entry whose red is >= r.
    var lo = 0, hi = length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_r[mid] < r) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    var best = -1;
    var bestDist = double.infinity;
    var up = lo, down = lo - 1;
    var upOpen = up < length, downOpen = down >= 0;

    while (upOpen || downOpen) {
      if (upOpen) {
        final dr = r - _r[up];
        if (dr * dr > bestDist) {
          upOpen = false;
        } else {
          final dg = g - _g[up], db = b - _b[up];
          final d = dr * dr + dg * dg + db * db;
          final k = _idx[up];
          if (d < bestDist || (d == bestDist && k < best)) {
            bestDist = d;
            best = k;
          }
          upOpen = ++up < length;
        }
      }
      if (downOpen) {
        final dr = r - _r[down];
        if (dr * dr > bestDist) {
          downOpen = false;
        } else {
          final dg = g - _g[down], db = b - _b[down];
          final d = dr * dr + dg * dg + db * db;
          final k = _idx[down];
          if (d < bestDist || (d == bestDist && k < best)) {
            bestDist = d;
            best = k;
          }
          downOpen = --down >= 0;
        }
      }
    }
    return best;
  }
}
