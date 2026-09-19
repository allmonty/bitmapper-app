import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bitmapper/models/media_model.dart';
import 'package:bitmapper/screens/home_screen.dart';
import 'package:bitmapper/services/filter_controller.dart';
import 'package:bitmapper/services/image_loader.dart';
import 'package:bitmapper/widgets/pixel_grid_view.dart';
import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

/// Paint [painter] the way the screen does (logical canvas scaled by the
/// pixel ratio) and read back the physical pixels as packed 0xRRGGBB.
Future<List<int>> rasterize(
  WidgetTester tester,
  PixelGridPainter painter,
  int width,
  int height,
) async {
  final dpr = painter.devicePixelRatio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(dpr);
  painter.paint(canvas, Size(width / dpr, height / dpr));
  final picture = recorder.endRecording();
  final bytes = (await tester.runAsync(() async {
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
  return packedColors(bytes, stride: 4);
}

/// A grid where every cell has a distinct color.
RgbImage distinctGrid(int cols, int rows) {
  final data = Uint8List(cols * rows * 3);
  for (var i = 0; i < cols * rows; i++) {
    data[i * 3] = (i * 37) & 255;
    data[i * 3 + 1] = (i * 91) & 255;
    data[i * 3 + 2] = i ~/ 7 & 255;
  }
  return RgbImage(cols, rows, data);
}

void main() {
  test('cellSize: the largest whole number of pixels per cell that fits', () {
    expect(PixelGridView.cellSize(120, 90, 1040, 1180), 8);
    expect(PixelGridView.cellSize(120, 160, 1040, 1180), 7);
    expect(PixelGridView.cellSize(512, 384, 400, 400), 1, reason: 'never below 1');
  });

  for (final dpr in [1.0, 2.8125, 3.75]) {
    testWidgets('cells are painted exactly: same size and color, at dpr $dpr', (tester) async {
      const cols = 12, rows = 9, cell = 7;
      final grid = distinctGrid(cols, rows);
      final pixels = await rasterize(
        tester,
        PixelGridPainter(grid: grid, cell: cell, devicePixelRatio: dpr),
        cols * cell,
        rows * cell,
      );
      for (var y = 0; y < rows * cell; y++) {
        for (var x = 0; x < cols * cell; x++) {
          final expected = packedAt(grid.data, ((y ~/ cell) * cols + x ~/ cell) * 3);
          expect(pixels[y * cols * cell + x], expected, reason: 'pixel ($x, $y)');
        }
      }
    });
  }

  testWidgets('gaps sit on interior cell edges only, like the export', (tester) async {
    const cols = 4, rows = 3, cell = 10;
    final grid = RgbImage(
      cols,
      rows,
      Uint8List(cols * rows * 3)..fillRange(0, cols * rows * 3, 255),
    );
    final pixels = await rasterize(
      tester,
      PixelGridPainter(grid: grid, cell: cell, devicePixelRatio: 1, gapPx: 2, gapColor: 0x00FF00),
      cols * cell,
      rows * cell,
    );
    // Same pixels as the engine's upscale with the same gap.
    final expected = upscale(grid, cols * cell, rows * cell, gapPx: 2, gapColor: [0, 255, 0]);
    for (var i = 0; i < pixels.length; i++) {
      expect(pixels[i], packedAt(expected.data, i * 3), reason: 'pixel $i');
    }
  });

  testWidgets('scanlines darken every other screen row, like the export', (tester) async {
    final grid = RgbImage(2, 2, Uint8List(12)..fillRange(0, 12, 200));
    final pixels = await rasterize(
      tester,
      PixelGridPainter(grid: grid, cell: 4, devicePixelRatio: 1, scanlines: 0.5),
      8,
      8,
    );
    final export = applyScanlines(upscale(grid, 8, 8), 0.5);
    for (var y = 0; y < 8; y++) {
      final got = redOf(pixels[y * 8]);
      expect((got - export.data[y * 8 * 3]).abs(), lessThanOrEqualTo(1), reason: 'row $y');
    }
  });

  for (final (label, size, dpr) in [
    ('QHD+', const Size(1440, 3120), 3.75),
    ('FHD+', const Size(1080, 2340), 2.8125),
  ]) {
    for (final (orientation, photo) in [('portrait', (3000, 4000)), ('landscape', (4000, 3000))]) {
      testWidgets(
        'S24 Ultra $label, $orientation photo: whole-pixel cells, filter renders only the grid',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = dpr;
          addTearDown(tester.view.reset);
          final app = TestApp(
            image: LoadedImage(name: 'photo.jpg', image: gradient(photo.$1, photo.$2)),
          );
          await tester.pumpWidget(app.build());
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open...'));
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          await tester.pumpAndSettle();

          final context = tester.element(find.byType(HomeScreen));
          final filter = Provider.of<FilterController>(context, listen: false);
          final media = Provider.of<MediaModel>(context, listen: false);
          final grid = filter.result!.grid;
          // The filter produced just the grid (one pixel per cell)...
          expect(
            (filter.result!.output.width, filter.result!.output.height),
            (grid.width, grid.height),
          );
          expect(
            grid.width / grid.height,
            closeTo(media.preview!.width / media.preview!.height, 0.02),
          );

          // ...and the view paints it with a whole number of screen pixels per cell.
          final view = find.byKey(const Key('preview-image'));
          final painted = tester.getSize(
            find.descendant(of: view, matching: find.byType(CustomPaint)).last,
          );
          final cellPx = painted.width * dpr / grid.width;
          expect(cellPx, closeTo(cellPx.roundToDouble(), 1e-6));
          expect(cellPx, greaterThanOrEqualTo(1));
          expect(painted.height * dpr / grid.height, closeTo(cellPx, 1e-6));
        },
      );
    }
  }
}
