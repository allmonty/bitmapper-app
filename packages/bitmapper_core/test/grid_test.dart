import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('splitSizes (np.array_split semantics)', () {
    test('front-loads the remainder', () {
      expect(splitSizes(100, 7), [15, 15, 14, 14, 14, 14, 14]);
      expect(splitSizes(10, 5), [2, 2, 2, 2, 2]);
    });
    test('produces empty trailing parts when n > length', () {
      expect(splitSizes(3, 5), [1, 1, 1, 0, 0]);
    });
    test('rejects n < 1', () {
      expect(() => splitSizes(3, 0), throwsArgumentError);
    });
  });

  // 7x5 image with values (i * 3) mod 256; expected values from the Python
  // reference (grid.downsample).
  RgbImage ramp() {
    final data = Uint8List(5 * 7 * 3);
    for (var i = 0; i < data.length; i++) {
      data[i] = (i * 3) & 0xFF;
    }
    return RgbImage(7, 5, data);
  }

  group('downsample', () {
    test('average matches the Python reference on uneven blocks', () {
      expect(downsample(ramp(), 3, 2).data,
          [72, 75, 78, 94, 97, 100, 112, 115, 118, 144, 147, 107, 124, 127, 130, 142, 145, 148]);
    });

    test('nearest samples each block center', () {
      expect(downsample(ramp(), 3, 2, mode: BlockSampling.nearest).data,
          [72, 75, 78, 99, 102, 105, 117, 120, 123, 5, 8, 11, 32, 35, 38, 50, 53, 56]);
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

    test('gutters match the Python reference (uneven, gap 1)', () {
      final out = upscale(grid, 5, 4, gapPx: 1, gapColor: [255, 0, 0]);
      expect(out.data, [
        10, 20, 30, 10, 20, 30, 10, 20, 30, 255, 0, 0, 40, 50, 60, //
        10, 20, 30, 10, 20, 30, 10, 20, 30, 255, 0, 0, 40, 50, 60, //
        255, 0, 0, 255, 0, 0, 255, 0, 0, 255, 0, 0, 255, 0, 0, //
        70, 80, 90, 70, 80, 90, 70, 80, 90, 255, 0, 0, 100, 110, 120,
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
