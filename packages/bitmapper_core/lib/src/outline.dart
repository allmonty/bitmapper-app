import 'dart:typed_data';

import 'color.dart';
import 'image.dart';
import 'quantize.dart';

/// Ways to find the edges to ink. Mirrors the Python
/// `bitmapper.outline.list_methods()`.
const kOutlineMethods = ['brightness', 'color', 'sobel'];

/// Ways to pick the ink color. Mirrors `bitmapper.outline.list_inks()`.
const kOutlineInks = ['darkest', 'shaded'];

/// Line thickness range, in grid cells. 1 is the original one-cell line.
const kMinOutlineThickness = 1;
const kMaxOutlineThickness = 3;

/// Brightness (or color) jump that counts as an edge: 128 at strength 0+,
/// down to 16 at strength 1 (stronger = more edges outlined).
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

/// Sprite-style ink outlines on the quantized `grid`, using one of
/// [kOutlineMethods] to find edges and one of [kOutlineInks] to color them.
/// `strength` 0 is off; 1 outlines the faintest edges. The output stays
/// within the palette.
///
/// Edges are detected on `edgeGrid` (defaulting to `grid` itself) but ink is
/// always painted onto `grid`. The pipeline passes the grid quantized before
/// dithering as `edgeGrid`, so a dither pattern's color noise in flat
/// regions isn't mistaken for real edges, while the ink color/placement
/// still reflects the actually rendered pixels.
///
/// `thickness` (1..3, [kMinOutlineThickness]..[kMaxOutlineThickness]) grows
/// the line by dilating the edge mask one 4-neighbour step per extra cell;
/// 1 (the default) is the original one-cell line.
RgbImage applyOutline(
  RgbImage grid,
  Uint8List palette,
  double strength, {
  String method = 'brightness',
  String ink = 'darkest',
  RgbImage? edgeGrid,
  int thickness = 1,
}) {
  if (strength < 0 || strength > 1) {
    throw ArgumentError.value(strength, 'strength', 'outline must be between 0 and 1');
  }
  if (!kOutlineMethods.contains(method)) {
    throw ArgumentError.value(method, 'method', 'invalid outline method');
  }
  if (!kOutlineInks.contains(ink)) {
    throw ArgumentError.value(ink, 'ink', 'invalid outline ink');
  }
  if (thickness < kMinOutlineThickness || thickness > kMaxOutlineThickness) {
    throw ArgumentError.value(
      thickness,
      'thickness',
      'must be $kMinOutlineThickness..$kMaxOutlineThickness',
    );
  }
  if (strength == 0 || grid.pixelCount == 0) return grid;
  final edges = edgeGrid ?? grid;
  if (edges.width != grid.width || edges.height != grid.height) {
    throw ArgumentError.value(edgeGrid, 'edgeGrid', "must be the same size as 'grid'");
  }

  final w = grid.width, h = grid.height, src = grid.data;
  final threshold = outlineThreshold(strength);
  var mask = switch (method) {
    'color' => _colorMask(edges, threshold),
    'sobel' => _sobelMask(edges, threshold),
    _ => _brightnessMask(edges, threshold),
  };
  for (var i = 1; i < thickness; i++) {
    mask = _dilate4(mask, w, h);
  }

  final out = Uint8List.fromList(src);
  if (ink == 'darkest') {
    final darkest = darkestColorIndex(palette) * 3;
    for (var p = 0; p < mask.length; p++) {
      if (mask[p]) out.setRange(p * 3, p * 3 + 3, palette, darkest);
    }
  } else {
    final search = PaletteSearch(palette);
    for (var p = 0; p < mask.length; p++) {
      if (!mask[p]) continue;
      final r = src[p * 3], g = src[p * 3 + 1], b = src[p * 3 + 2];
      final k = search.nearest((r >> 1).toDouble(), (g >> 1).toDouble(), (b >> 1).toDouble());
      final ki = k * 3;
      if (palette[ki] == r && palette[ki + 1] == g && palette[ki + 2] == b) {
        out.setRange(p * 3, p * 3 + 3, palette, darkestColorIndex(palette) * 3);
      } else {
        out.setRange(p * 3, p * 3 + 3, palette, ki);
      }
    }
  }
  return RgbImage(w, h, out);
}

/// Grows `mask` by one cell in each of the 4 cardinal directions (a plus
/// shape per step), which tapers more gracefully than 8-neighbour dilation
/// when applied repeatedly for [applyOutline]'s `thickness`.
List<bool> _dilate4(List<bool> mask, int w, int h) {
  final out = List<bool>.from(mask);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = y * w + x;
      if (mask[p]) continue;
      out[p] =
          (x + 1 < w && mask[p + 1]) ||
          (x > 0 && mask[p - 1]) ||
          (y + 1 < h && mask[p + w]) ||
          (y > 0 && mask[p - w]);
    }
  }
  return out;
}

Float64List _luminanceGrid(RgbImage grid) {
  final src = grid.data;
  final lum = Float64List(grid.pixelCount);
  for (var p = 0; p < lum.length; p++) {
    lum[p] = luminance(src[p * 3], src[p * 3 + 1], src[p * 3 + 2]);
  }
  return lum;
}

/// A cell is an edge when a 4-neighbour is brighter by more than
/// [threshold].
List<bool> _brightnessMask(RgbImage grid, double threshold) {
  final w = grid.width, h = grid.height;
  final lum = _luminanceGrid(grid);
  final mask = List<bool>.filled(w * h, false);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = y * w + x;
      final l = lum[p];
      mask[p] =
          (x + 1 < w && lum[p + 1] - l > threshold) ||
          (x > 0 && lum[p - 1] - l > threshold) ||
          (y + 1 < h && lum[p + w] - l > threshold) ||
          (y > 0 && lum[p - w] - l > threshold);
    }
  }
  return mask;
}

/// Like [_brightnessMask] but by RGB distance, so it also catches edges
/// between hues of similar brightness. The darker of each pair is inked
/// (the first cell on equal brightness).
List<bool> _colorMask(RgbImage grid, double threshold) {
  final w = grid.width, h = grid.height, src = grid.data;
  final lum = _luminanceGrid(grid);
  final mask = List<bool>.filled(w * h, false);
  final limit = 3.0 * threshold * threshold;
  double sqDist(int a, int b) {
    final dr = (src[a * 3] - src[b * 3]).toDouble();
    final dg = (src[a * 3 + 1] - src[b * 3 + 1]).toDouble();
    final db = (src[a * 3 + 2] - src[b * 3 + 2]).toDouble();
    return dr * dr + dg * dg + db * db;
  }

  void inkDarker(int a, int b) {
    if (sqDist(a, b) <= limit) return;
    if (lum[a] <= lum[b]) {
      mask[a] = true;
    } else {
      mask[b] = true;
    }
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = y * w + x;
      if (x + 1 < w) inkDarker(p, p + 1);
      if (y + 1 < h) inkDarker(p, p + w);
    }
  }
  return mask;
}

/// A 3x3 Sobel gradient of the brightness (edges padded by extending the
/// border), inked on the side darker than its own 3x3 neighbourhood
/// average. Finds diagonal and gradual edges that [_brightnessMask] misses.
List<bool> _sobelMask(RgbImage grid, double threshold) {
  final w = grid.width, h = grid.height;
  final lum = _luminanceGrid(grid);
  double at(int x, int y) => lum[y.clamp(0, h - 1) * w + x.clamp(0, w - 1)];

  final mask = List<bool>.filled(w * h, false);
  // A brightness step of `threshold` between neighbours gives a Sobel
  // magnitude of about 4 * threshold.
  final strongLimit = 16.0 * threshold * threshold;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final tl = at(x - 1, y - 1), t = at(x, y - 1), tr = at(x + 1, y - 1);
      final ml = at(x - 1, y), mc = at(x, y), mr = at(x + 1, y);
      final bl = at(x - 1, y + 1), b = at(x, y + 1), br = at(x + 1, y + 1);
      final gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
      final gy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr);
      final strong = gx * gx + gy * gy > strongLimit;
      final total = (tl + t + tr) + (ml + mc + mr) + (bl + b + br);
      mask[y * w + x] = strong && mc * 9.0 < total;
    }
  }
  return mask;
}
