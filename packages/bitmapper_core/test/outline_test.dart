import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const gray = [128, 128, 128], white = [255, 255, 255], black = [0, 0, 0];
final palette = Uint8List.fromList([...white, ...gray, ...black]);

/// 7x7 gray grid with a white 3x3 square in the middle.
RgbImage square() => imageFromRows([
  for (var y = 0; y < 7; y++)
    [for (var x = 0; x < 7; x++) (x >= 2 && x < 5 && y >= 2 && y < 5) ? white : gray],
]);

void main() {
  test('strength 0 is a no-op', () {
    final grid = square();
    expect(identical(applyOutline(grid, palette, 0), grid), isTrue);
  });

  test('inks the dark side of strong edges, one cell thick', () {
    final out = applyOutline(square(), palette, 0.5);
    for (var y = 0; y < 7; y++) {
      for (var x = 0; x < 7; x++) {
        final inSquare = x >= 2 && x < 5 && y >= 2 && y < 5;
        final beside =
            !inSquare &&
            ((x >= 2 && x < 5 && (y == 1 || y == 5)) || (y >= 2 && y < 5 && (x == 1 || x == 5)));
        expect(out.pixel(x, y), inSquare ? white : (beside ? black : gray), reason: '($x, $y)');
      }
    }
  });

  test('weak edges need more strength', () {
    final grid = imageFromRows([
      [gray, gray, gray],
      [
        gray,
        [178, 178, 178],
        gray,
      ],
      [gray, gray, gray],
    ]);
    expect(applyOutline(grid, palette, 0.5).data, grid.data); // threshold 72
    final out = applyOutline(grid, palette, 1.0); // threshold 16
    expect(out.pixel(1, 0), black);
    expect(out.pixel(1, 1), [178, 178, 178]);
  });

  test('threshold range and darkest color (first on ties)', () {
    expect(outlineThreshold(0), 128);
    expect(outlineThreshold(1), 16);
    final ties = Uint8List.fromList([...white, 10, 10, 10, 10, 10, 10, ...gray]);
    expect(darkestColorIndex(ties), 1);
  });

  test('rejects out-of-range strength', () {
    expect(() => applyOutline(square(), palette, 1.5), throwsArgumentError);
    expect(const BitmapFilterConfig(outline: -0.1).validate, throwsArgumentError);
    expect(const BitmapFilterConfig(outline: 1.1).validate, throwsArgumentError);
  });

  test('rejects an invalid method or ink', () {
    expect(() => applyOutline(square(), palette, 0.5, method: 'nonsense'), throwsArgumentError);
    expect(
      () => applyOutline(square(), palette, 0.5, method: 'brightness', ink: 'nonsense'),
      throwsArgumentError,
    );
    expect(const BitmapFilterConfig(outlineMethod: 'nonsense').validate, throwsArgumentError);
    expect(const BitmapFilterConfig(outlineInk: 'nonsense').validate, throwsArgumentError);
  });

  test('rejects an out-of-range thickness', () {
    for (final thickness in [0, 4]) {
      expect(() => applyOutline(square(), palette, 0.5, thickness: thickness), throwsArgumentError);
      expect(BitmapFilterConfig(outlineThickness: thickness).validate, throwsArgumentError);
    }
  });

  test('lists the methods and inks', () {
    expect(kOutlineMethods, ['brightness', 'color', 'sobel']);
    expect(kOutlineInks, ['darkest', 'shaded']);
  });

  test('color method also catches same-brightness hue edges', () {
    // Red and green cells of identical luminance: brightness sees no edge,
    // color does.
    const red = [255, 0, 0], green = [0, 130, 0];
    final grid = imageFromRows([
      [red, green],
    ]);
    final pal = Uint8List.fromList([...red, ...green, ...black]);
    expect(applyOutline(grid, pal, 0.9, method: 'brightness').data, grid.data);
    expect(applyOutline(grid, pal, 0.9, method: 'color').data, isNot(grid.data));
  });

  test('sobel method also catches diagonal edges', () {
    final grid = imageFromRows([
      [white, gray, gray],
      [gray, gray, gray],
      [gray, gray, gray],
    ]);
    expect(applyOutline(grid, palette, 0.9, method: 'brightness').pixel(1, 1), gray);
    expect(applyOutline(grid, palette, 0.9, method: 'sobel').pixel(1, 1), black);
  });

  test('shaded ink uses a half-brightness palette match', () {
    final pal = Uint8List.fromList([...white, ...gray, 64, 64, 64, ...black]);
    final out = applyOutline(square(), pal, 0.5, method: 'brightness', ink: 'shaded');
    // Half of gray (128) is 64, which is in the palette, so shaded ink picks
    // it instead of falling back to the darkest color.
    expect(out.pixel(2, 1), [64, 64, 64]);
  });

  for (final (mode, config) in [
    ('auto', const BitmapFilterConfig(gridCols: 10, gridRows: 10, bitDepth: 3, outline: 0.6)),
    (
      'fixed',
      const BitmapFilterConfig(
        gridCols: 10,
        gridRows: 10,
        paletteMode: PaletteMode.fixed,
        fixedPalette: 'pico8',
        bitDepth: 4,
        outline: 0.6,
      ),
    ),
    (
      'true color',
      const BitmapFilterConfig(gridCols: 10, gridRows: 10, bitDepth: 24, outline: 0.6),
    ),
    (
      'dithered',
      const BitmapFilterConfig(
        gridCols: 10,
        gridRows: 10,
        bitDepth: 3,
        dither: 'floyd_steinberg',
        outline: 0.6,
        outlineMethod: 'sobel',
      ),
    ),
  ]) {
    test('pipeline output stays within the palette ($mode)', () {
      final r = applyBitmapFilter(randomImage(40, 40), config);
      expect(onlyUsesPalette(r.grid, r.palette), isTrue);
    });
  }

  test('the pipeline applies it to the grid, before upscaling', () {
    final src = square(); // 7x7 source, one pixel per cell
    const config = BitmapFilterConfig(
      gridCols: 7,
      gridRows: 7,
      paletteMode: PaletteMode.custom,
      customPalette: [0xFFFFFF, 0x808080, 0x000000],
      outline: 0.5,
    );
    final r = applyBitmapFilter(src, config, outputWidth: 14, outputHeight: 14);
    expect(r.grid.data, applyOutline(src, palette, 0.5).data);
    // Cell (1, 2) is inked; upscaled 2x it covers output pixels (2..3, 4..5).
    expect(r.output.pixel(2, 4), black);
    expect(r.output.pixel(3, 5), black);
    expect(r.output.pixel(0, 0), gray);
  });

  test('true color inks with the darkest color already in the grid', () {
    const config = BitmapFilterConfig(gridCols: 7, gridRows: 7, bitDepth: 24, outline: 0.5);
    final r = applyBitmapFilter(square(), config);
    expect(r.grid.data, square().data, reason: 'gray is the darkest color, so ink is invisible');
  });

  group('edgeGrid (detect edges before dithering)', () {
    test('omitting edgeGrid equals passing the same grid', () {
      final grid = square();
      expect(
        applyOutline(grid, palette, 0.5, method: 'sobel', edgeGrid: grid).data,
        applyOutline(grid, palette, 0.5, method: 'sobel').data,
      );
    });

    test('a dither boundary invisible in edgeGrid is not inked', () {
      // The middle cell's final color is darker than its neighbours (as
      // dither noise would leave it in a flat white region), but its
      // pre-dither mapping agrees with them: it should only be inked
      // (darkened further, to the palette's darkest color) without
      // edgeGrid.
      final finalGrid = imageFromRows([
        [white, gray, white],
      ]);
      final preDither = imageFromRows([
        [white, white, white],
      ]);
      final pal = Uint8List.fromList([...white, ...gray, ...black]);
      final withoutEdgeGrid = applyOutline(finalGrid, pal, 0.9, method: 'brightness');
      final withEdgeGrid = applyOutline(
        finalGrid,
        pal,
        0.9,
        method: 'brightness',
        edgeGrid: preDither,
      );
      expect(withoutEdgeGrid.pixel(1, 0), isNot(gray), reason: 'sees a real jump and inks it');
      expect(withEdgeGrid.pixel(1, 0), gray, reason: 'pre-dither, all three cells agree');
    });

    test('rejects an edgeGrid of a different size', () {
      expect(
        () => applyOutline(square(), palette, 0.5, edgeGrid: solidImage(1, 1, black)),
        throwsArgumentError,
      );
    });

    test('detects fewer edges from dither noise than from the final grid', () {
      // A smooth gradient dithered onto a small palette: Floyd-Steinberg
      // scatters color noise across the whole gradient, which the final
      // grid alone can't tell apart from a real edge. The pre-dither grid
      // has far fewer real edges (only at the palette's band boundaries).
      final gray4 = Uint8List.fromList([0, 0, 0, 85, 85, 85, 170, 170, 170, 255, 255, 255]);
      final source = gradientImage();
      final dithered = applyDither(source, gray4, 'floyd_steinberg');
      final preDither = RgbImage(source.width, source.height, nearestColor(source.data, gray4));

      int inkedCount(RgbImage out, RgbImage original) {
        var n = 0;
        for (var p = 0; p < out.data.length; p += 3) {
          if (out.data[p] != original.data[p] ||
              out.data[p + 1] != original.data[p + 1] ||
              out.data[p + 2] != original.data[p + 2]) {
            n++;
          }
        }
        return n;
      }

      final withoutEdgeGrid = applyOutline(dithered, gray4, 1.0, method: 'sobel');
      final withEdgeGrid = applyOutline(dithered, gray4, 1.0, method: 'sobel', edgeGrid: preDither);
      final noisyCount = inkedCount(withoutEdgeGrid, dithered);
      final cleanCount = inkedCount(withEdgeGrid, dithered);
      expect(cleanCount, lessThan(noisyCount));
      // Empirically ~35-40% fewer across several dither methods; leave
      // headroom so the test isn't brittle to small algorithm tweaks.
      expect(cleanCount, lessThan((noisyCount * 0.75).round()));
    });
  });

  group('thickness', () {
    test('1 (the default) reproduces the one-cell-thick line', () {
      expect(
        applyOutline(square(), palette, 0.5, thickness: 1).data,
        applyOutline(square(), palette, 0.5).data,
      );
    });

    test('grows the line by one cell per step, tapering diagonally', () {
      // A single inked cell in the middle of an otherwise-uninked field:
      // thickness 2 should grow it to a plus shape (4-neighbours), and
      // thickness 3 should reach the diagonals too (dilated twice).
      final grid = imageFromRows([
        for (var y = 0; y < 5; y++)
          [for (var x = 0; x < 5; x++) (x == 2 && y == 2) ? black : white],
      ]);
      final pal = Uint8List.fromList([...white, ...black]);
      bool isBlack(RgbImage out, int x, int y) => out.pixel(x, y)[0] == 0;

      final t1 = applyOutline(grid, pal, 0.5, thickness: 1);
      expect(isBlack(t1, 1, 2), isFalse);
      expect(isBlack(t1, 2, 2), isTrue);

      final t2 = applyOutline(grid, pal, 0.5, thickness: 2);
      expect(isBlack(t2, 1, 2), isTrue, reason: 'plus shape: left neighbour');
      expect(isBlack(t2, 2, 1), isTrue, reason: 'plus shape: top neighbour');
      expect(isBlack(t2, 1, 1), isFalse, reason: 'not yet reached diagonally');

      final t3 = applyOutline(grid, pal, 0.5, thickness: 3);
      expect(isBlack(t3, 1, 1), isTrue, reason: 'diagonal, reached after 2 dilation steps');
    });

    test('matches the Python reference byte for byte', () {
      final grid = RgbImage(
        6,
        5,
        Uint8List.fromList(List.generate(6 * 5 * 3, (i) => i * 37 % 256)),
      );
      final pal = Uint8List.fromList([200, 30, 30, 5, 60, 90, 240, 240, 240, 12, 40, 20]);
      expect(applyOutline(grid, pal, 0.35, method: 'sobel', thickness: 2).data, [
        12,
        40,
        20,
        12,
        40,
        20,
        222,
        3,
        40,
        77,
        114,
        151,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        9,
        46,
        83,
        120,
        157,
        194,
        231,
        12,
        49,
        86,
        123,
        160,
        12,
        40,
        20,
        52,
        89,
        126,
        163,
        200,
        237,
        18,
        55,
        92,
        129,
        166,
        203,
        240,
        21,
        58,
        95,
        132,
        169,
        206,
        243,
        24,
        61,
        98,
        135,
        172,
        209,
        246,
        27,
        64,
        101,
        138,
        175,
        212,
        249,
        30,
        67,
        104,
        141,
        178,
        215,
        252,
        33,
        70,
        107,
        144,
        181,
        218,
        255,
        36,
        73,
        110,
        147,
        184,
        221,
      ]);
      expect(applyOutline(grid, pal, 0.35, method: 'sobel', thickness: 3).data, [
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        120,
        157,
        194,
        231,
        12,
        49,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        163,
        200,
        237,
        18,
        55,
        92,
        129,
        166,
        203,
        240,
        21,
        58,
        12,
        40,
        20,
        206,
        243,
        24,
        61,
        98,
        135,
        172,
        209,
        246,
        27,
        64,
        101,
        138,
        175,
        212,
        249,
        30,
        67,
        104,
        141,
        178,
        215,
        252,
        33,
        70,
        107,
        144,
        181,
        218,
        255,
        36,
        73,
        110,
        147,
        184,
        221,
      ]);
    });
  });

  group('closeGaps', () {
    test('off (the default) reproduces every prior golden', () {
      final grid = square();
      expect(
        applyOutline(grid, palette, 0.5, closeGaps: false).data,
        applyOutline(grid, palette, 0.5).data,
      );
    });

    /// 7x7, bright everywhere except a dark 3x3 ring (rows/cols 2-4)
    /// around a bright center cell (3,3): a single-cell gap in an
    /// otherwise fully-enclosed dark ring.
    RgbImage ringGrid() {
      final data = Uint8List(7 * 7 * 3);
      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < 7; x++) {
          final inRingBlock = x >= 2 && x <= 4 && y >= 2 && y <= 4;
          final isCenter = x == 3 && y == 3;
          data.setRange(
            (y * 7 + x) * 3,
            (y * 7 + x) * 3 + 3,
            (inRingBlock && !isCenter) ? black : white,
          );
        }
      }
      return RgbImage(7, 7, data);
    }

    test('bridges a gap fully enclosed by inked cells', () {
      final pal = Uint8List.fromList([...white, ...black]);
      final withoutClose = applyOutline(ringGrid(), pal, 0.5, method: 'brightness');
      final withClose = applyOutline(ringGrid(), pal, 0.5, method: 'brightness', closeGaps: true);
      expect(withoutClose.pixel(3, 3), white, reason: 'the ring has a 1-cell gap at its centre');
      expect(withClose.pixel(3, 3), black, reason: 'closing bridges a fully-enclosed gap');
    });

    test('matches the Python reference byte for byte', () {
      final grid = RgbImage(
        6,
        5,
        Uint8List.fromList(List.generate(6 * 5 * 3, (i) => i * 37 % 256)),
      );
      final pal = Uint8List.fromList([200, 30, 30, 5, 60, 90, 240, 240, 240, 12, 40, 20]);
      expect(applyOutline(grid, pal, 0.35, method: 'brightness', closeGaps: true).data, [
        12,
        40,
        20,
        12,
        40,
        20,
        222,
        3,
        40,
        77,
        114,
        151,
        188,
        225,
        6,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        120,
        157,
        194,
        231,
        12,
        49,
        86,
        123,
        160,
        197,
        234,
        15,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        240,
        21,
        58,
        95,
        132,
        169,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        138,
        175,
        212,
        249,
        30,
        67,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
        12,
        40,
        20,
      ]);
    });
  });

  test('matches the Python reference byte for byte', () {
    final grid = RgbImage(6, 5, Uint8List.fromList(List.generate(6 * 5 * 3, (i) => i * 37 % 256)));
    final pal = Uint8List.fromList([200, 30, 30, 5, 60, 90, 240, 240, 240, 12, 40, 20]);
    expect(applyOutline(grid, pal, 0.35).data, [
      12,
      40,
      20,
      111,
      148,
      185,
      222,
      3,
      40,
      77,
      114,
      151,
      188,
      225,
      6,
      12,
      40,
      20,
      154,
      191,
      228,
      12,
      40,
      20,
      120,
      157,
      194,
      231,
      12,
      49,
      86,
      123,
      160,
      197,
      234,
      15,
      12,
      40,
      20,
      163,
      200,
      237,
      12,
      40,
      20,
      129,
      166,
      203,
      240,
      21,
      58,
      95,
      132,
      169,
      206,
      243,
      24,
      12,
      40,
      20,
      172,
      209,
      246,
      12,
      40,
      20,
      138,
      175,
      212,
      249,
      30,
      67,
      104,
      141,
      178,
      215,
      252,
      33,
      12,
      40,
      20,
      181,
      218,
      255,
      12,
      40,
      20,
      147,
      184,
      221,
    ]);
  });

  for (final (method, ink, expected) in [
    (
      'color',
      'darkest',
      [
        12,
        40,
        20,
        111,
        148,
        185,
        12,
        40,
        20,
        12,
        40,
        20,
        188,
        225,
        6,
        12,
        40,
        20,
        154,
        191,
        228,
        12,
        40,
        20,
        120,
        157,
        194,
        12,
        40,
        20,
        12,
        40,
        20,
        197,
        234,
        15,
        12,
        40,
        20,
        163,
        200,
        237,
        12,
        40,
        20,
        129,
        166,
        203,
        12,
        40,
        20,
        12,
        40,
        20,
        206,
        243,
        24,
        12,
        40,
        20,
        172,
        209,
        246,
        12,
        40,
        20,
        138,
        175,
        212,
        12,
        40,
        20,
        12,
        40,
        20,
        215,
        252,
        33,
        12,
        40,
        20,
        181,
        218,
        255,
        12,
        40,
        20,
        147,
        184,
        221,
      ],
    ),
    (
      'sobel',
      'darkest',
      [
        12,
        40,
        20,
        111,
        148,
        185,
        222,
        3,
        40,
        77,
        114,
        151,
        188,
        225,
        6,
        12,
        40,
        20,
        154,
        191,
        228,
        9,
        46,
        83,
        120,
        157,
        194,
        231,
        12,
        49,
        86,
        123,
        160,
        197,
        234,
        15,
        52,
        89,
        126,
        163,
        200,
        237,
        18,
        55,
        92,
        129,
        166,
        203,
        240,
        21,
        58,
        95,
        132,
        169,
        206,
        243,
        24,
        61,
        98,
        135,
        172,
        209,
        246,
        27,
        64,
        101,
        138,
        175,
        212,
        249,
        30,
        67,
        104,
        141,
        178,
        215,
        252,
        33,
        70,
        107,
        144,
        181,
        218,
        255,
        36,
        73,
        110,
        147,
        184,
        221,
      ],
    ),
    (
      'brightness',
      'shaded',
      [
        12,
        40,
        20,
        111,
        148,
        185,
        222,
        3,
        40,
        77,
        114,
        151,
        188,
        225,
        6,
        12,
        40,
        20,
        154,
        191,
        228,
        12,
        40,
        20,
        120,
        157,
        194,
        231,
        12,
        49,
        86,
        123,
        160,
        197,
        234,
        15,
        5,
        60,
        90,
        163,
        200,
        237,
        12,
        40,
        20,
        129,
        166,
        203,
        240,
        21,
        58,
        95,
        132,
        169,
        206,
        243,
        24,
        5,
        60,
        90,
        172,
        209,
        246,
        12,
        40,
        20,
        138,
        175,
        212,
        249,
        30,
        67,
        104,
        141,
        178,
        215,
        252,
        33,
        5,
        60,
        90,
        181,
        218,
        255,
        12,
        40,
        20,
        147,
        184,
        221,
      ],
    ),
  ]) {
    test('matches the Python reference byte for byte ($method, $ink)', () {
      final grid = RgbImage(
        6,
        5,
        Uint8List.fromList(List.generate(6 * 5 * 3, (i) => i * 37 % 256)),
      );
      final pal = Uint8List.fromList([200, 30, 30, 5, 60, 90, 240, 240, 240, 12, 40, 20]);
      expect(applyOutline(grid, pal, 0.35, method: method, ink: ink).data, expected);
    });
  }

  test('config JSON round-trips the outline', () {
    const c = BitmapFilterConfig(outline: 0.4);
    expect(BitmapFilterConfig.fromJson(c.toJson()).outline, 0.4);
    expect(c, isNot(const BitmapFilterConfig()));
  });
}
