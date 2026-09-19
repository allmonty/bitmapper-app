import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const red = [255, 0, 0], green = [0, 255, 0], blue = [0, 0, 255];

RgbImage grayRamp() => RgbImage(
  16,
  16,
  Uint8List.fromList([
    for (var v = 0; v < 256; v++) ...[v, v, v],
  ]),
);

void main() {
  group('shade bands', () {
    test('0 is a no-op', () {
      final grid = randomImage(8, 8);
      expect(identical(applyShadeBands(grid, 0), grid), isTrue);
    });

    for (final bands in [2, 3, 4, 8]) {
      test('a gray ramp collapses to exactly $bands band centres', () {
        final out = applyShadeBands(grayRamp(), bands);
        final levels = {for (var i = 0; i < out.data.length; i += 3) out.data[i]}.toList()..sort();
        expect(levels, [for (var b = 0; b < bands; b++) ((b + 0.5) * 255.0 / bands).toInt()]);
      });
    }

    test('hue is kept', () {
      final out = applyShadeBands(
        imageFromRows([
          [
            [200, 100, 50],
          ],
        ]),
        3,
      ).pixel(0, 0);
      expect(out[0] / out[1], closeTo(2.0, 0.04));
      expect(out[1] / out[2], closeTo(2.0, 0.1));
    });

    test('black becomes the darkest band gray', () {
      expect(applyShadeBands(solidImage(1, 1, [0, 0, 0]), 4).pixel(0, 0), [31, 31, 31]);
    });

    test('hue is kept even when brightening would clip a channel', () {
      // Old algorithm: factor ~1.376 pushes r=220 past 255, truncating it
      // back to 255 while g/b keep scaling, distorting the ratio.
      final out = applyShadeBands(
        imageFromRows([
          [
            [220, 40, 30],
          ],
        ]),
        3,
      ).pixel(0, 0);
      expect(out[0], lessThanOrEqualTo(255));
      expect(out[0] / out[1], closeTo(220 / 40, 0.1));
      expect(out[1] / out[2], closeTo(40 / 30, 0.15));
    });

    test('hue stays close for saturated colors at every band count', () {
      // A regression guard for the whole class of the bug above: none of
      // these ratios should move far from the source once brightening no
      // longer silently clips a channel.
      const saturated = [
        [255, 60, 30],
        [60, 255, 30],
        [30, 60, 255],
        [255, 200, 30],
        [230, 90, 210],
      ];
      for (final bands in [2, 3, 4, 5, 6, 7, 8]) {
        for (final color in saturated) {
          final out = applyShadeBands(solidImage(1, 1, color), bands).pixel(0, 0);
          for (var i = 0; i < 3; i++) {
            for (var j = 0; j < 3; j++) {
              if (color[j] == 0 || out[j] == 0) continue;
              final expected = color[i] / color[j];
              expect(out[i] / out[j], closeTo(expected, expected * 0.15 + 0.1));
            }
          }
        }
      }
    });

    test('rejects invalid band counts', () {
      for (final bands in [1, 9, -1]) {
        expect(() => applyShadeBands(grayRamp(), bands), throwsArgumentError);
        expect(BitmapFilterConfig(shadeBands: bands).validate, throwsArgumentError);
      }
    });
  });

  group('despeckle', () {
    test('isolated cells take the most common neighbour color', () {
      final grid = imageFromRows([
        [green, green, green],
        [green, red, green],
        [green, green, green],
      ]);
      expect(colorSet(despeckle(grid).data), {0x00FF00});
    });

    test('cells with a matching neighbour are kept', () {
      final grid = imageFromRows([
        [green, green, green, green],
        [green, red, red, green],
        [green, green, green, green],
      ]);
      expect(despeckle(grid).data, grid.data);
    });

    test('ties go to the first neighbour in reading order', () {
      final grid = imageFromRows([
        [blue, blue, blue],
        [blue, red, green],
        [green, green, green],
      ]);
      expect(despeckle(grid).pixel(1, 1), blue);
    });

    test('never adds colors; a single cell is unchanged', () {
      final grid = randomImage(12, 12);
      expect(colorSet(grid.data).containsAll(colorSet(despeckle(grid).data)), isTrue);
      final one = imageFromRows([
        [red],
      ]);
      expect(despeckle(one).data, one.data);
    });
  });

  group('pipeline and presets', () {
    for (final name in ['toon', 'toon_pastel']) {
      test('$name combines bands, despeckle and outline', () {
        final p = getPreset(name);
        expect(p.shadeBands, greaterThan(0));
        expect(p.despeckle, isTrue);
        expect(p.outline, greaterThan(0));
        expect(presetColumns(name), 96);
        final r = applyBitmapFilter(randomImage(48, 48), p.copyWith(gridCols: 12, gridRows: 12));
        expect(onlyUsesPalette(r.grid, r.palette), isTrue);
      });
    }

    test('shade bands run before the palette is built', () {
      final img = upscale(grayRamp(), 32, 32);
      const config = BitmapFilterConfig(gridCols: 16, gridRows: 16, bitDepth: 4, shadeBands: 2);
      expect(colorSet(applyBitmapFilter(img, config).grid.data).length, lessThanOrEqualTo(2));
    });

    test('config JSON round-trips the toon fields', () {
      const c = BitmapFilterConfig(shadeBands: 3, despeckle: true);
      final back = BitmapFilterConfig.fromJson(c.toJson());
      expect((back.shadeBands, back.despeckle), (3, true));
      expect(back, c);
    });
  });

  group('matches the Python reference byte for byte', () {
    RgbImage sharedGrid() {
      final data = Uint8List.fromList(List.generate(6 * 5 * 3, (i) => i * 53 % 256));
      data.fillRange(0, 3, 0);
      return RgbImage(6, 5, data);
    }

    RgbImage sharedSpeckles() {
      const colors = [red, green, blue];
      final rows = [
        for (var y = 0; y < 5; y++)
          [for (var x = 0; x < 6; x++) colors[((x * 7 + y * 3) ~/ 5) % 3]],
      ];
      rows[2][2] = [9, 9, 9];
      return imageFromRows(rows);
    }

    test('shade bands', () {
      expect(applyShadeBands(sharedGrid(), 3).data, [
        42,
        42,
        42,
        191,
        254,
        10,
        75,
        139,
        203,
        110,
        9,
        35,
        94,
        134,
        175,
        16,
        48,
        80,
        197,
        253,
        38,
        85,
        136,
        188,
        255,
        46,
        100,
        116,
        157,
        0,
        70,
        140,
        209,
        117,
        5,
        34,
        92,
        135,
        177,
        12,
        49,
        85,
        196,
        255,
        30,
        83,
        137,
        191,
        255,
        39,
        95,
        146,
        200,
        255,
        65,
        141,
        217,
        126,
        1,
        34,
        91,
        135,
        180,
        8,
        50,
        91,
        194,
        255,
        22,
        80,
        138,
        196,
        254,
        31,
        90,
        142,
        198,
        255,
        19,
        47,
        75,
        198,
        251,
        47,
        89,
        136,
        183,
        2,
        51,
        100,
      ]);
      expect(applyShadeBands(sharedGrid(), 5).data, [
        25,
        25,
        25,
        164,
        218,
        9,
        75,
        139,
        203,
        199,
        16,
        64,
        132,
        188,
        245,
        29,
        87,
        144,
        165,
        213,
        32,
        85,
        136,
        188,
        255,
        46,
        100,
        163,
        220,
        1,
        42,
        84,
        125,
        212,
        9,
        62,
        130,
        189,
        248,
        23,
        88,
        153,
        165,
        214,
        26,
        83,
        137,
        191,
        255,
        39,
        95,
        137,
        187,
        238,
        39,
        84,
        130,
        228,
        2,
        61,
        91,
        135,
        180,
        15,
        90,
        165,
        164,
        216,
        19,
        80,
        138,
        196,
        185,
        23,
        65,
        135,
        188,
        241,
        35,
        85,
        135,
        200,
        255,
        47,
        89,
        136,
        183,
        1,
        30,
        60,
      ]);
    });

    test('despeckle', () {
      expect(despeckle(sharedSpeckles()).data, [
        255,
        0,
        0,
        255,
        0,
        0,
        0,
        0,
        255,
        0,
        255,
        0,
        0,
        255,
        0,
        0,
        255,
        0,
        255,
        0,
        0,
        0,
        0,
        255,
        0,
        0,
        255,
        0,
        255,
        0,
        255,
        0,
        0,
        0,
        255,
        0,
        0,
        255,
        0,
        0,
        0,
        255,
        0,
        0,
        255,
        255,
        0,
        0,
        255,
        0,
        0,
        0,
        0,
        255,
        0,
        255,
        0,
        255,
        0,
        0,
        255,
        0,
        0,
        255,
        0,
        0,
        0,
        0,
        255,
        0,
        0,
        255,
        255,
        0,
        0,
        255,
        0,
        0,
        255,
        0,
        0,
        255,
        0,
        0,
        0,
        0,
        255,
        0,
        0,
        255,
      ]);
    });
  });
}
