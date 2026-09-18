import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  for (final algorithm in kPaletteAlgorithms) {
    group(algorithm, () {
      Uint8List gen(RgbImage img, int n) =>
          generatePalette(img.data, n, algorithm: algorithm);

      test('returns the requested number of colors', () {
        for (final n in [1, 2, 4, 16, 64]) {
          expect(gen(randomImage(30, 30), n).length, n * 3);
        }
      });

      test('is deterministic', () {
        final img = randomImage(30, 30, seed: 5);
        expect(gen(img, 8), gen(img, 8));
      });

      test('single-color image degrades gracefully (padding)', () {
        final pal = gen(solidImage(4, 4, [200, 50, 10]), 4);
        expect(colorsOf(pal), {0xC8320A});
      });

      test('two-color image recovers both colors', () {
        expect(colorsOf(gen(checkerboardImage(), 2)), {0x000000, 0xFFFFFF});
      });

      test('rejects n < 1', () {
        expect(() => gen(randomImage(4, 4), 0), throwsArgumentError);
      });
    });
  }

  test('median cut matches the Python reference on distinct colors', () {
    const rimg = [248, 194, 190, 207, 147, 26, 237, 21, 245, 211, 239, 45, 5, 157, 159, 60, 54, 236, 109, 46, 199, 82, 32, 205, 36, 7, 134, 222, 57, 146, 8, 149, 14, 15, 22, 10, 144, 208, 24, 24, 7, 41, 11, 85, 59, 104, 225, 110, 226, 201, 8, 159, 26, 27, 163, 122, 33, 41, 201, 67, 70, 166, 228, 40, 50, 179, 0, 177, 137, 63, 13, 188, 255, 64, 94, 8, 8, 156, 25, 29, 157, 146, 190, 115, 219, 135, 39, 100, 237, 127, 72, 227, 168, 21, 73, 132, 16, 153, 140, 107, 80, 163, 61, 110, 47, 229, 148, 170];
    expect(medianCut(Uint8List.fromList(rimg), 4),
        [187, 151, 45, 164, 111, 173, 24, 92, 71, 39, 95, 179]);
  });

  test('uniqueColors sorts lexicographically', () {
    final rgb = Uint8List.fromList([2, 0, 0, 1, 5, 5, 1, 0, 9, 2, 0, 0]);
    expect(uniqueColors(rgb), [0x010009, 0x010505, 0x020000]);
  });

  test('kmeans is population weighted', () {
    // 15 near-red pixels vs 1 blue: the single center lands near red.
    final rgb = Uint8List.fromList([
      for (var i = 0; i < 15; i++) ...[250 - i, 0, 0],
      0, 0, 255,
    ]);
    final pal = kmeans(rgb, 1);
    expect(pal[0], greaterThan(200));
  });

  test('unknown algorithm throws', () {
    expect(() => generatePalette(Uint8List(3), 2, algorithm: 'nope'), throwsArgumentError);
  });
}
