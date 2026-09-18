import 'dart:typed_data';

import 'image.dart';
import 'quantize.dart';

const kPaletteAlgorithms = ['median_cut', 'kmeans'];

/// Unique colors of a flat RGB buffer, sorted lexicographically (like
/// `np.unique(axis=0)`), as packed `0xRRGGBB` ints.
List<int> uniqueColors(Uint8List rgb) {
  final seen = <int>{};
  for (var i = 0; i < rgb.length; i += 3) {
    seen.add((rgb[i] << 16) | (rgb[i + 1] << 8) | rgb[i + 2]);
  }
  return seen.toList()..sort();
}

int _ch(int packed, int c) => (packed >> (16 - 8 * c)) & 0xFF;

double _bucketPriority(List<int> bucket) {
  if (bucket.length <= 1) return -1.0;
  var maxRange = 0;
  for (var c = 0; c < 3; c++) {
    var lo = 255, hi = 0;
    for (final p in bucket) {
      final v = _ch(p, c);
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if (hi - lo > maxRange) maxRange = hi - lo;
  }
  return maxRange.toDouble() * bucket.length;
}

/// Stable sort, since `List.sort` makes no stability guarantee.
void _stableSort<T>(List<T> list, int Function(T a, T b) compare) {
  final indexed = List.generate(list.length, (i) => (i, list[i]));
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  for (var i = 0; i < list.length; i++) {
    list[i] = indexed[i].$2;
  }
}

/// Stable O(n) sort of packed colors by one 8-bit channel.
List<int> _countingSortByChannel(List<int> colors, int channel) {
  final counts = List<int>.filled(257, 0);
  for (final p in colors) {
    counts[_ch(p, channel) + 1]++;
  }
  for (var v = 1; v < 257; v++) {
    counts[v] += counts[v - 1];
  }
  final out = List<int>.filled(colors.length, 0);
  for (final p in colors) {
    out[counts[_ch(p, channel)]++] = p;
  }
  return out;
}

Uint8List _padPalette(List<List<int>> colors, int nColors) {
  final out = Uint8List(nColors * 3);
  if (colors.isEmpty) return out;
  for (var i = 0; i < nColors; i++) {
    final c = colors[i < colors.length ? i : colors.length - 1];
    out[i * 3] = c[0];
    out[i * 3 + 1] = c[1];
    out[i * 3 + 2] = c[2];
  }
  return out;
}

/// Median-cut quantization over the image's unique colors: repeatedly split
/// the bucket with the largest `range * population` along its widest channel.
///
/// Unlike NumPy's default (unstable) argsort, the split sort here is stable,
/// so results are fully deterministic.
Uint8List medianCut(Uint8List rgb, int nColors) {
  if (nColors < 1) throw ArgumentError.value(nColors, 'nColors', 'must be >= 1');
  final buckets = <List<int>>[uniqueColors(rgb)];

  while (buckets.length < nColors) {
    // Stable-sort by priority and take the last bucket, exactly like the
    // Python `buckets.sort(key=...)`; priorities are computed once per pass.
    final priorities = [for (final b in buckets) _bucketPriority(b)];
    final order = List<int>.generate(buckets.length, (i) => i);
    _stableSort<int>(order, (a, b) => priorities[a].compareTo(priorities[b]));
    final reordered = [for (final i in order) buckets[i]];
    buckets
      ..clear()
      ..addAll(reordered);
    final bucket = buckets.last;
    if (bucket.length <= 1) break;
    buckets.removeLast();

    var channel = 0, bestRange = -1;
    for (var c = 0; c < 3; c++) {
      var lo = 255, hi = 0;
      for (final p in bucket) {
        final v = _ch(p, c);
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
      if (hi - lo > bestRange) {
        bestRange = hi - lo;
        channel = c;
      }
    }
    final sorted = _countingSortByChannel(bucket, channel);
    final mid = sorted.length ~/ 2;
    buckets.add(sorted.sublist(0, mid));
    buckets.add(sorted.sublist(mid));
  }

  final colors = <List<int>>[];
  for (final bucket in buckets) {
    if (bucket.isEmpty) continue;
    final sums = [0.0, 0.0, 0.0];
    for (final p in bucket) {
      for (var c = 0; c < 3; c++) {
        sums[c] += _ch(p, c);
      }
    }
    colors.add([for (final s in sums) clampToByte(s / bucket.length)]);
  }
  return _padPalette(colors, nColors);
}

/// Lloyd's k-means over all pixels (so it is population-weighted), with a
/// deterministic initialization: `k` evenly-spaced entries of the sorted
/// unique colors (migration doc §6.4b). Empty clusters keep their center.
Uint8List kmeans(Uint8List rgb, int nColors, {int iterations = 10}) {
  if (nColors < 1) throw ArgumentError.value(nColors, 'nColors', 'must be >= 1');
  final unique = uniqueColors(rgb);
  if (unique.isEmpty) return _padPalette(const [], nColors);
  final k = nColors < unique.length ? nColors : unique.length;

  var centers = Float64List(k * 3);
  for (var i = 0; i < k; i++) {
    final u = k == 1 ? 0 : (i * (unique.length - 1)) ~/ (k - 1);
    for (var c = 0; c < 3; c++) {
      centers[i * 3 + c] = _ch(unique[u], c).toDouble();
    }
  }

  final pixelCount = rgb.length ~/ 3;
  for (var it = 0; it < iterations; it++) {
    final sums = Float64List(k * 3);
    final counts = Int32List(k);
    for (var p = 0; p < pixelCount; p++) {
      final r = rgb[p * 3].toDouble(), g = rgb[p * 3 + 1].toDouble(), b = rgb[p * 3 + 2].toDouble();
      final best = nearestCenterIndex(r, g, b, centers);
      sums[best * 3] += r;
      sums[best * 3 + 1] += g;
      sums[best * 3 + 2] += b;
      counts[best]++;
    }
    final next = Float64List.fromList(centers);
    for (var i = 0; i < k; i++) {
      if (counts[i] > 0) {
        for (var c = 0; c < 3; c++) {
          next[i * 3 + c] = sums[i * 3 + c] / counts[i];
        }
      }
    }
    centers = next;
  }

  final colors = [
    for (var i = 0; i < k; i++)
      [for (var c = 0; c < 3; c++) clampToByte(centers[i * 3 + c])],
  ];
  return _padPalette(colors, nColors);
}

/// Build an `nColors` palette from the image's own colors.
Uint8List generatePalette(Uint8List rgb, int nColors,
    {String algorithm = 'median_cut'}) {
  switch (algorithm) {
    case 'median_cut':
      return medianCut(rgb, nColors);
    case 'kmeans':
      return kmeans(rgb, nColors);
  }
  throw ArgumentError('unknown palette algorithm: "$algorithm"');
}
