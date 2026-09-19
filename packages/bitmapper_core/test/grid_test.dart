import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('splitSizes', () {
    test('spreads the remainder evenly instead of front-loading it', () {
      // np.array_split would give [15, 15, 14, 14, 14, 14, 14].
      expect(splitSizes(100, 7), [14, 14, 14, 15, 14, 14, 15]);
      expect(splitSizes(10, 5), [2, 2, 2, 2, 2]);
    });

    test('sizes differ by at most 1 and every boundary is within 1 of exact', () {
      for (final (length, n) in [(1024, 120), (1024, 300), (4000, 120), (768, 97), (5, 3)]) {
        final sizes = splitSizes(length, n);
        expect(sizes.reduce((a, b) => a + b), length);
        expect(sizes.reduce((a, b) => a > b ? a : b) - sizes.reduce((a, b) => a < b ? a : b),
            lessThanOrEqualTo(1));
        final starts = splitStarts(sizes);
        for (var i = 0; i < n; i++) {
          expect((starts[i] - i * length / n).abs(), lessThan(1), reason: '$length/$n part $i');
        }
      }
    });

    test('spreads empty parts when n > length', () {
      expect(splitSizes(3, 5), [0, 1, 0, 1, 1]);
    });

    test('rejects n < 1', () {
      expect(() => splitSizes(3, 0), throwsArgumentError);
    });
  });

  test('no squeeze-then-stretch: features keep their position at any column count', () {
    // A 1024 px wide image, dark left of x = 768 (three quarters), light right.
    const w = 1024, h = 8;
    final img = RgbImage.blank(w, h);
    for (var y = 0; y < h; y++) {
      for (var x = 768; x < w; x++) {
        img.data.fillRange((y * w + x) * 3, (y * w + x) * 3 + 3, 255);
      }
    }
    for (final cols in [60, 97, 120, 200, 300, 512]) {
      final grid = downsample(img, cols, 1);
      final firstLight = List.generate(cols, (x) => grid.data[x * 3]).indexWhere((v) => v > 127);
      // The edge stays at three quarters of the grid (within one cell).
      expect((firstLight - cols * 0.75).abs(), lessThanOrEqualTo(1), reason: '$cols columns');
    }
  });

  // 7x5 image with values (i * 3) mod 256. Blocks are 2, 2, 3 columns and 2, 3
  // rows (evenly spread); expected values computed independently.
  RgbImage ramp() {
    final data = Uint8List(5 * 7 * 3);
    for (var i = 0; i < data.length; i++) {
      data[i] = (i * 3) & 0xFF;
    }
    return RgbImage(7, 5, data);
  }

  group('downsample', () {
    test('average over uneven blocks', () {
      expect(downsample(ramp(), 3, 2).data,
          [36, 39, 42, 54, 57, 60, 76, 79, 82, 150, 153, 114, 126, 129, 132, 148, 151, 154]);
    });

    test('nearest samples each block center', () {
      expect(downsample(ramp(), 3, 2, mode: BlockSampling.nearest).data,
          [72, 75, 78, 90, 93, 96, 108, 111, 114, 198, 201, 204, 216, 219, 222, 234, 237, 240]);
    });

    test('evenly divisible blocks average exactly', () {
      final img = imageFromRows([
        [[0, 0, 0], [10, 20, 30], [100, 100, 100], [100, 100, 100]],
        [[20, 40, 60], [10, 20, 30], [100, 100, 100], [100, 100, 100]],
      ]);
      final out = downsample(img, 2, 1);
      expect(out.width, 2);
      expect(out.height, 1);
      expect(out.data, [10, 20, 30, 100, 100, 100]);
    });

    test('average truncates instead of rounding', () {
      final img = imageFromRows([
        [[0, 0, 0], [1, 1, 1]],
      ]);
      expect(downsample(img, 1, 1).data, [0, 0, 0]);
    });

    test('grid larger than the image does not crash', () {
      final out = downsample(solidImage(2, 2, [9, 8, 7]), 5, 3);
      expect(out.width, 5);
      expect(out.height, 3);
      expect(colorsOf(out.data), {0x090807});
    });

    test('rejects an empty grid', () {
      expect(() => downsample(solidImage(2, 2, [0, 0, 0]), 0, 1), throwsArgumentError);
    });
  });

  group('upscale', () {
    final grid = imageFromRows([
      [[10, 20, 30], [40, 50, 60]],
      [[70, 80, 90], [100, 110, 120]],
    ]);

    test('replicates cells into blocks', () {
      final out = upscale(grid, 4, 4);
      expect(out.pixel(0, 0), [10, 20, 30]);
      expect(out.pixel(1, 1), [10, 20, 30]);
      expect(out.pixel(3, 0), [40, 50, 60]);
      expect(out.pixel(0, 3), [70, 80, 90]);
      expect(out.pixel(3, 3), [100, 110, 120]);
    });

    test('gutters on uneven blocks (columns 2 + 3, gap 1)', () {
      final out = upscale(grid, 5, 4, gapPx: 1, gapColor: [255, 0, 0]);
      expect(out.data, [
        10, 20, 30, 10, 20, 30, 255, 0, 0, 40, 50, 60, 40, 50, 60, //
        10, 20, 30, 10, 20, 30, 255, 0, 0, 40, 50, 60, 40, 50, 60, //
        255, 0, 0, 255, 0, 0, 255, 0, 0, 255, 0, 0, 255, 0, 0, //
        70, 80, 90, 70, 80, 90, 255, 0, 0, 100, 110, 120, 100, 110, 120,
      ]);
    });

    test('no gutter is drawn on the canvas edge', () {
      final out = upscale(grid, 8, 8, gapPx: 2);
      expect(out.pixel(0, 0), [10, 20, 30]);
      expect(out.pixel(7, 7), [100, 110, 120]);
      expect(out.pixel(3, 0), [0, 0, 0]);
      expect(out.pixel(4, 0), [0, 0, 0]);
      expect(out.pixel(2, 0), [10, 20, 30]);
    });

    test('round trip keeps the image blocky', () {
      final small = downsample(randomImage(40, 40), 5, 5);
      final big = upscale(small, 40, 40);
      expect(downsample(big, 5, 5).data, small.data);
    });
  });
}
