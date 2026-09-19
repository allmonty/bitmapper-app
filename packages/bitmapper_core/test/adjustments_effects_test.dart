import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final colors = imageFromRows([
    [
      [200, 50, 10],
      [30, 160, 90],
      [250, 250, 250],
      [0, 0, 0],
    ],
  ]);

  group('adjustments', () {
    test('all-1.0 is a no-op (same instance)', () {
      expect(identical(applyAdjustments(colors), colors), isTrue);
    });

    test('chained result matches the Python reference', () {
      final out = applyAdjustments(colors, contrast: 1.3, saturation: 0.6, gamma: 1.4);
      expect(out.data, [186, 77, 57, 71, 169, 121, 255, 255, 255, 0, 0, 0]);
    });

    test('contrast 0 collapses to mid gray (127, truncated)', () {
      expect(colorsOf(adjustContrast(colors, 0).data), {0x7F7F7F});
    });

    test('contrast > 1 pushes values away from the middle', () {
      final out = adjustContrast(colors, 2);
      expect(out.pixel(0, 0)[0], greaterThan(200));
      expect(out.pixel(0, 0)[2], 0);
    });

    test('saturation 0 is grayscale', () {
      final out = adjustSaturation(colors, 0);
      for (var x = 0; x < 4; x++) {
        final p = out.pixel(x, 0);
        expect(p[0], p[1]);
        expect(p[1], p[2]);
      }
    });

    test('saturation > 1 spreads channels', () {
      final before = colors.pixel(0, 0);
      final after = adjustSaturation(colors, 1.5).pixel(0, 0);
      expect(after[0] - after[2], greaterThan(before[0] - before[2]));
    });

    test('gamma > 1 brightens midtones and keeps endpoints', () {
      final gray = solidImage(1, 1, [128, 128, 128]);
      expect(adjustGamma(gray, 2).pixel(0, 0)[0], greaterThan(128));
      expect(adjustGamma(gray, 0.5).pixel(0, 0)[0], lessThan(128));
      final ends = imageFromRows([
        [
          [0, 0, 0],
          [255, 255, 255],
        ],
      ]);
      expect(adjustGamma(ends, 2.2).data, ends.data);
    });

    test('rejects invalid amounts', () {
      expect(() => adjustContrast(colors, -0.1), throwsArgumentError);
      expect(() => adjustSaturation(colors, -0.1), throwsArgumentError);
      expect(() => adjustGamma(colors, 0), throwsArgumentError);
    });
  });

  group('scanlines', () {
    test('darkens odd rows only (matches Python)', () {
      final out = applyScanlines(solidImage(2, 3, [200, 200, 200]), 0.35);
      expect(out.data, [
        200, 200, 200, 200, 200, 200, //
        130, 130, 130, 130, 130, 130, //
        200, 200, 200, 200, 200, 200,
      ]);
    });

    test('strength 0 is a no-op', () {
      final img = solidImage(2, 2, [9, 9, 9]);
      expect(identical(applyScanlines(img, 0), img), isTrue);
    });

    test('strength 1 blacks out odd rows', () {
      final out = applyScanlines(solidImage(1, 2, [255, 255, 255]), 1);
      expect(out.pixel(0, 1), [0, 0, 0]);
      expect(out.pixel(0, 0), [255, 255, 255]);
    });

    test('rejects out-of-range strength', () {
      expect(() => applyScanlines(solidImage(1, 1, [0, 0, 0]), 1.1), throwsArgumentError);
      expect(() => applyScanlines(solidImage(1, 1, [0, 0, 0]), -0.1), throwsArgumentError);
    });
  });
}
