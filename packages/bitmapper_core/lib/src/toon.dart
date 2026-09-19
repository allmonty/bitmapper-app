import 'dart:math' as math;
import 'dart:typed_data';

import 'color.dart';
import 'image.dart';
import 'outline.dart' show applyOutline;

/// Toon (cel) shading stages that run on the grid:
///
/// - [applyShadeBands] flattens brightness into a few bands while keeping
///   each cell's hue, before palette mapping;
/// - [despeckle] removes isolated cells after quantization, so flat regions
///   stay flat.
///
/// Together with [applyOutline] (ink lines) they give a cel-shaded look.
const kMinShadeBands = 2;
const kMaxShadeBands = 8;

/// Snap each cell's luminance to the centre of one of `bands` equal bands,
/// rescaling its RGB so the hue is kept. `bands` 0 is off.
///
/// Per cell, in the Python reference's operation order:
/// `band = min(bands - 1, floor(luma * bands / 256))`,
/// `target = (band + 0.5) * 255 / bands`, then `factor = target / luma`,
/// capped so no channel would exceed 255 (`min(factor, 255 / maxChannel)`,
/// which only ever reduces a brightening `factor`, never a darkening one),
/// then each channel is `channel * factor`, clamped and truncated. Black
/// cells become gray at `target`.
RgbImage applyShadeBands(RgbImage grid, int bands) {
  if (bands == 0) return grid;
  if (bands < kMinShadeBands || bands > kMaxShadeBands) {
    throw ArgumentError.value(
      bands,
      'bands',
      'shade bands must be 0 (off) or $kMinShadeBands..$kMaxShadeBands',
    );
  }
  final src = grid.data;
  final out = Uint8List(src.length);
  for (var i = 0; i < src.length; i += 3) {
    final r = src[i], g = src[i + 1], b = src[i + 2];
    final luma = luminance(r, g, b);
    final band = math.min(bands - 1, (luma * bands / 256.0).floor());
    final target = (band + 0.5) * 255.0 / bands;
    if (luma > 0) {
      final maxChannel = math.max(r, math.max(g, b)).toDouble();
      final factor = math.min(target / luma, 255.0 / maxChannel);
      out[i] = clampToByte(r * factor);
      out[i + 1] = clampToByte(g * factor);
      out[i + 2] = clampToByte(b * factor);
    } else {
      out.fillRange(i, i + 3, clampToByte(target));
    }
  }
  return RgbImage(grid.width, grid.height, out);
}

/// Neighbour offsets for [despeckle], in reading order (top-left first).
/// Ties between equally common neighbour colors go to the first one here.
const _neighbours = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)];

/// Replace every isolated cell (one whose color matches none of its 8
/// neighbours) with its most common neighbour color. Reads the original
/// grid, so the result doesn't depend on scan order. Never adds colors.
RgbImage despeckle(RgbImage grid) {
  final w = grid.width, h = grid.height, src = grid.data;
  int packed(int p) => packedAt(src, p * 3);
  final out = Uint8List.fromList(src);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final me = packed(y * w + x);
      // Neighbour colors in first-seen order, with their counts.
      final colors = <int>[];
      final counts = <int>[];
      var isolated = true;
      for (final (dx, dy) in _neighbours) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
        final c = packed(ny * w + nx);
        if (c == me) {
          isolated = false;
          break;
        }
        final k = colors.indexOf(c);
        if (k < 0) {
          colors.add(c);
          counts.add(1);
        } else {
          counts[k]++;
        }
      }
      if (!isolated || colors.isEmpty) continue;
      var best = 0;
      for (var k = 1; k < colors.length; k++) {
        if (counts[k] > counts[best]) best = k;
      }
      out.setAll((y * w + x) * 3, unpackRgb(colors[best]));
    }
  }
  return RgbImage(w, h, out);
}
