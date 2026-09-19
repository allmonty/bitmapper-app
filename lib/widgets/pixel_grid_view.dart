import 'dart:math' as math;

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';

import 'rgb_image_view.dart';

/// Shows a filtered grid by painting every cell as a solid rectangle: no
/// image is created or resized, so nothing can be stretched or resampled.
///
/// Each cell is the same whole number of screen pixels, the largest that
/// fits. Grid gaps and scanlines are painted on top, at screen resolution.
/// With `original` set, that image is shown in the same rectangle instead
/// (hold to compare).
class PixelGridView extends StatelessWidget {
  const PixelGridView({
    super.key,
    required this.grid,
    this.gapPx = 0,
    this.gapColor = 0x000000,
    this.scanlines = 0,
    this.original,
    this.semanticLabel,
  });

  /// One pixel per cell, as produced by the filter.
  final RgbImage grid;

  /// Gutter between cells, in screen pixels.
  final int gapPx;
  final int gapColor;

  /// 0..1: how much every other screen row is darkened.
  final double scanlines;
  final RgbImage? original;
  final String? semanticLabel;

  /// Whole screen pixels per cell for a `cols x rows` grid in a
  /// `width x height` area (physical pixels); at least 1.
  static int cellSize(int cols, int rows, int width, int height) =>
      math.max(1, math.min(width ~/ cols, height ~/ rows));

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = cellSize(
          grid.width,
          grid.height,
          (constraints.maxWidth * dpr).floor(),
          (constraints.maxHeight * dpr).floor(),
        );
        final size = Size(grid.width * cell / dpr, grid.height * cell / dpr);
        final Widget content = original != null
            ? RgbImageView(image: original!)
            : RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: PixelGridPainter(
                    grid: grid,
                    cell: cell,
                    devicePixelRatio: dpr,
                    gapPx: gapPx,
                    gapColor: gapColor,
                    scanlines: scanlines,
                  ),
                ),
              );
        return Semantics(
          image: true,
          label: semanticLabel,
          child: Center(
            // Only when even one pixel per cell doesn't fit (huge grids on
            // small screens) is the whole thing scaled down.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox.fromSize(size: size, child: content),
            ),
          ),
        );
      },
    );
  }
}

/// Paints [grid] with `cell` physical pixels per cell. Runs of equal
/// colors in a row are merged into one rectangle.
class PixelGridPainter extends CustomPainter {
  PixelGridPainter({
    required this.grid,
    required this.cell,
    required this.devicePixelRatio,
    this.gapPx = 0,
    this.gapColor = 0x000000,
    this.scanlines = 0,
  });

  final RgbImage grid;
  final int cell;
  final double devicePixelRatio;
  final int gapPx;
  final int gapColor;
  final double scanlines;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = cell / devicePixelRatio; // logical size of one cell
    final paint = Paint()..isAntiAlias = false;
    final data = grid.data;
    final cols = grid.width;

    for (var y = 0; y < grid.height; y++) {
      var runStart = 0;
      var runColor = packedAt(data, y * cols * 3);
      for (var x = 1; x <= cols; x++) {
        final color = x < cols ? packedAt(data, (y * cols + x) * 3) : -1;
        if (color == runColor) continue;
        paint.color = Color(0xFF000000 | runColor);
        canvas.drawRect(
          Rect.fromLTWH(runStart * unit, y * unit, (x - runStart) * unit, unit),
          paint,
        );
        runStart = x;
        runColor = color;
      }
    }

    final px = 1 / devicePixelRatio; // one physical pixel, in logical units
    if (gapPx > 0) {
      // Same placement as the engine's upscale: centred on each interior
      // cell edge, never on the outer border.
      paint.color = Color(0xFF000000 | gapColor);
      final half = gapPx ~/ 2;
      for (var x = 1; x < cols; x++) {
        canvas.drawRect(Rect.fromLTWH((x * cell - half) * px, 0, gapPx * px, size.height), paint);
      }
      for (var y = 1; y < grid.height; y++) {
        canvas.drawRect(Rect.fromLTWH(0, (y * cell - half) * px, size.width, gapPx * px), paint);
      }
    }

    if (scanlines > 0) {
      // Darken odd screen rows by `scanlines`, like the engine's scanline
      // effect (multiplying by 1 - strength == black at alpha strength).
      paint.color = Color.fromARGB((scanlines * 255).round(), 0, 0, 0);
      final rows = (size.height * devicePixelRatio).round();
      for (var r = 1; r < rows; r += 2) {
        canvas.drawRect(Rect.fromLTWH(0, r * px, size.width, px), paint);
      }
    }
  }

  @override
  bool shouldRepaint(PixelGridPainter old) =>
      !identical(old.grid, grid) ||
      old.cell != cell ||
      old.devicePixelRatio != devicePixelRatio ||
      old.gapPx != gapPx ||
      old.gapColor != gapColor ||
      old.scanlines != scanlines;
}
