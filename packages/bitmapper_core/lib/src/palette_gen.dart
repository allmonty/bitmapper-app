import 'dart:typed_data';

import 'color.dart';
import 'image.dart';
import 'quantize.dart';

const kPaletteAlgorithms = ['median_cut', 'kmeans'];

/// Unique colors of a flat RGB buffer, sorted lexicographically (like
/// `np.unique(axis=0)`), as packed `0xRRGGBB` ints.
List<int> uniqueColors(Uint8List rgb) => colorSet(rgb).toList()..sort();

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
  // Python re-sorts the whole bucket list by priority (stable) on every
  // pass and splits the last one. Keeping the list sorted and inserting the
  // two halves with an upper-bound search gives the identical order, since
  // the halves were appended after every existing bucket; priorities are
  // computed once per bucket. On the final pass Python appends the halves
  // without sorting again, and palette order matters for ties, so do too.
  final buckets = <List<int>>[uniqueColors(rgb)];
  final priorities = <double>[_bucketPriority(buckets.first)];

  void insertSorted(List<int> bucket) {
    final priority = _bucketPriority(bucket);
    var lo = 0, hi = priorities.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (priorities[mid] <= priority) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    buckets.insert(lo, bucket);
    priorities.insert(lo, priority);
  }

  while (buckets.length < nColors) {
    final bucket = buckets.last;
    if (bucket.length <= 1) break;
    buckets.removeLast();
    priorities.removeLast();

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
    final low = sorted.sublist(0, mid), high = sorted.sublist(mid);
    if (buckets.length + 2 >= nColors) {
      buckets
        ..add(low)
        ..add(high);
    } else {
      insertSorted(low);
      insertSorted(high);
    }
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
    final search = PaletteSearch.floats(centers);
    final sums = Float64List(k * 3);
    final counts = Int32List(k);
    for (var p = 0; p < pixelCount; p++) {
      final r = rgb[p * 3].toDouble(), g = rgb[p * 3 + 1].toDouble(), b = rgb[p * 3 + 2].toDouble();
      final best = search.nearest(r, g, b);
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
    for (var i = 0; i < k; i++) [for (var c = 0; c < 3; c++) clampToByte(centers[i * 3 + c])],
  ];
  return _padPalette(colors, nColors);
}

/// Build an `nColors` palette from the image's own colors.
Uint8List generatePalette(Uint8List rgb, int nColors, {String algorithm = 'median_cut'}) {
  switch (algorithm) {
    case 'median_cut':
      return medianCut(rgb, nColors);
    case 'kmeans':
      return kmeans(rgb, nColors);
  }
  throw ArgumentError('unknown palette algorithm: "$algorithm"');
}
