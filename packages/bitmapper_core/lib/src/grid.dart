import 'dart:typed_data';

import 'image.dart';

/// Sizes of `n` consecutive parts covering `length`, as even as possible and
/// evenly spread: part `i` spans `[i * length ~/ n, (i + 1) * length ~/ n)`.
/// Sizes differ by at most 1, and every boundary is within one unit of its
/// exact position. When `n > length` some parts are empty.
///
/// This deliberately differs from `np.array_split` in the Python reference,
/// which gives all the extra units to the first parts: that squeezes the
/// start of an image into its cells and stretches the rest (e.g. 1024 px in
/// 120 columns: 64 cells of 9 px, then 56 of 8), a visible distortion that
/// changes with the column count.
List<int> splitSizes(int length, int n) {
  if (n < 1) throw ArgumentError.value(n, 'n', 'must be >= 1');
  return List<int>.generate(n, (i) => (i + 1) * length ~/ n - i * length ~/ n);
}

/// Start offsets matching [splitSizes].
List<int> splitStarts(List<int> sizes) {
  final starts = List<int>.filled(sizes.length, 0);
  var acc = 0;
  for (var i = 0; i < sizes.length; i++) {
    starts[i] = acc;
    acc += sizes[i];
  }
  return starts;
}

enum BlockSampling { average, nearest }

/// Collapse `image` onto a `cols x rows` grid.
///
/// [BlockSampling.average] is a box-filter mean of each block (computed as
/// `sum / rowCount / colCount`, in that order, then truncated);
/// [BlockSampling.nearest] samples each block's center pixel.
RgbImage downsample(RgbImage image, int cols, int rows,
    {BlockSampling mode = BlockSampling.average}) {
  if (cols < 1 || rows < 1) {
    throw ArgumentError('grid size must be >= 1, got ${cols}x$rows');
  }
  final w = image.width;
  final h = image.height;
  final src = image.data;
  final rowSizes = splitSizes(h, rows);
  final colSizes = splitSizes(w, cols);
  final rowStarts = splitStarts(rowSizes);
  final colStarts = splitStarts(colSizes);
  final out = Uint8List(cols * rows * 3);

  // Empty parts (grid larger than the image) reuse the nearest real pixel
  // instead of crashing.
  int clampIdx(int i, int length) => i >= length ? length - 1 : i;

  if (mode == BlockSampling.nearest) {
    for (var gy = 0; gy < rows; gy++) {
      final sy = clampIdx(rowStarts[gy] + rowSizes[gy] ~/ 2, h);
      for (var gx = 0; gx < cols; gx++) {
        final sx = clampIdx(colStarts[gx] + colSizes[gx] ~/ 2, w);
        final si = (sy * w + sx) * 3;
        final oi = (gy * cols + gx) * 3;
        out[oi] = src[si];
        out[oi + 1] = src[si + 1];
        out[oi + 2] = src[si + 2];
      }
    }
    return RgbImage(cols, rows, out);
  }

  // Average: sum columns into per-block accumulators one source row at a
  // time, so each source pixel is read exactly once.
  final acc = Float64List(cols * 3);
  for (var gy = 0; gy < rows; gy++) {
    acc.fillRange(0, acc.length, 0);
    var rowCount = rowSizes[gy];
    var y0 = rowStarts[gy];
    if (rowCount == 0) {
      rowCount = 1;
      y0 = clampIdx(y0, h);
    }
    for (var y = y0; y < y0 + rowCount; y++) {
      final rowBase = y * w * 3;
      for (var gx = 0; gx < cols; gx++) {
        var colCount = colSizes[gx];
        var x0 = colStarts[gx];
        if (colCount == 0) {
          colCount = 1;
          x0 = clampIdx(x0, w);
        }
        var r = 0.0, g = 0.0, b = 0.0;
        var si = rowBase + x0 * 3;
        for (var x = 0; x < colCount; x++, si += 3) {
          r += src[si];
          g += src[si + 1];
          b += src[si + 2];
        }
        acc[gx * 3] += r;
        acc[gx * 3 + 1] += g;
        acc[gx * 3 + 2] += b;
      }
    }
    for (var gx = 0; gx < cols; gx++) {
      final colCount = colSizes[gx] == 0 ? 1 : colSizes[gx];
      final oi = (gy * cols + gx) * 3;
      for (var c = 0; c < 3; c++) {
        out[oi + c] = clampToByte(acc[gx * 3 + c] / rowCount / colCount);
      }
    }
  }
  return RgbImage(cols, rows, out);
}

/// Replicate each grid cell up to `outWidth x outHeight`, nearest-neighbor
/// style. When `gapPx > 0`, a gutter in `gapColor` is drawn on every interior
/// block boundary (never on the canvas edge).
RgbImage upscale(RgbImage grid, int outWidth, int outHeight,
    {int gapPx = 0, List<int> gapColor = const [0, 0, 0]}) {
  if (gapPx < 0) throw ArgumentError.value(gapPx, 'gapPx', 'must be >= 0');
  final rowRepeats = splitSizes(outHeight, grid.height);
  final colRepeats = splitSizes(outWidth, grid.width);
  final out = Uint8List(outWidth * outHeight * 3);
  final src = grid.data;

  // Source column for every output column, computed once.
  final colMap = Int32List(outWidth);
  for (var gx = 0, x = 0; gx < grid.width; gx++) {
    for (var i = 0; i < colRepeats[gx]; i++) {
      colMap[x++] = gx;
    }
  }

  var y = 0;
  for (var gy = 0; gy < grid.height; gy++) {
    if (rowRepeats[gy] == 0) continue;
    final firstRow = y * outWidth * 3;
    final srcRow = gy * grid.width * 3;
    for (var x = 0; x < outWidth; x++) {
      final si = srcRow + colMap[x] * 3;
      final oi = firstRow + x * 3;
      out[oi] = src[si];
      out[oi + 1] = src[si + 1];
      out[oi + 2] = src[si + 2];
    }
    for (var r = 1; r < rowRepeats[gy]; r++) {
      final dst = (y + r) * outWidth * 3;
      out.setRange(dst, dst + outWidth * 3, out, firstRow);
    }
    y += rowRepeats[gy];
  }

  if (gapPx > 0) {
    final half = gapPx ~/ 2;
    final fr = gapColor[0], fg = gapColor[1], fb = gapColor[2];
    void fillPixel(int i) {
      out[i] = fr;
      out[i + 1] = fg;
      out[i + 2] = fb;
    }

    var edge = 0;
    for (var i = 0; i < rowRepeats.length - 1; i++) {
      edge += rowRepeats[i];
      final lo = edge - half < 0 ? 0 : edge - half;
      final hi = edge + gapPx - half > outHeight ? outHeight : edge + gapPx - half;
      for (var yy = lo; yy < hi; yy++) {
        for (var x = 0; x < outWidth; x++) {
          fillPixel((yy * outWidth + x) * 3);
        }
      }
    }
    edge = 0;
    for (var i = 0; i < colRepeats.length - 1; i++) {
      edge += colRepeats[i];
      final lo = edge - half < 0 ? 0 : edge - half;
      final hi = edge + gapPx - half > outWidth ? outWidth : edge + gapPx - half;
      for (var yy = 0; yy < outHeight; yy++) {
        for (var x = lo; x < hi; x++) {
          fillPixel((yy * outWidth + x) * 3);
        }
      }
    }
  }
  return RgbImage(outWidth, outHeight, out);
}
