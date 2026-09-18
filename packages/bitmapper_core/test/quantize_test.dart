import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:test/test.dart';

void main() {
  final palette = Uint8List.fromList([0, 0, 0, 255, 255, 255, 255, 0, 0]);

  test('picks the closest palette entry', () {
    expect(nearestIndex(10, 10, 10, palette), 0);
    expect(nearestIndex(240, 250, 245, palette), 1);
    expect(nearestIndex(200, 30, 20, palette), 2);
  });

  test('ties go to the lowest index', () {
    final dup = Uint8List.fromList([10, 10, 10, 10, 10, 10]);
    expect(nearestIndex(10, 10, 10, dup), 0);
    final equidistant = Uint8List.fromList([0, 0, 0, 20, 20, 20]);
    expect(nearestIndex(10, 10, 10, equidistant), 0);
  });

  test('accepts fractional input', () {
    expect(nearestIndex(127.4, 127.4, 127.4, Uint8List.fromList([0, 0, 0, 255, 255, 255])), 0);
    expect(nearestIndex(127.6, 127.6, 127.6, Uint8List.fromList([0, 0, 0, 255, 255, 255])), 1);
  });

  test('nearestColor only emits palette colors', () {
    final rgb = Uint8List.fromList([1, 2, 3, 250, 240, 230, 180, 20, 10]);
    expect(nearestColor(rgb, palette), [0, 0, 0, 255, 255, 255, 255, 0, 0]);
  });

  test('nearestCenterIndex matches nearestIndex on integer centers', () {
    final centers = Float64List.fromList(palette.map((v) => v.toDouble()).toList());
    for (final c in [
      [0.0, 0.0, 0.0],
      [128.0, 128.0, 128.0],
      [200.0, 10.0, 0.0],
    ]) {
      expect(
        nearestCenterIndex(c[0], c[1], c[2], centers),
        nearestIndex(c[0], c[1], c[2], palette),
      );
    }
  });

  group('PaletteSearch', () {
    // Deterministic pseudo-random bytes.
    final rng = XorShift128Plus(99);
    int byte() => rng.nextInt64() & 0xFF;

    for (final size in [1, 2, 7, 24, 25, 64, 256, 1000, 4096]) {
      test('matches nearestIndex exactly for a $size-color palette', () {
        // Coarse values force many exact ties and duplicate entries.
        final palette = Uint8List.fromList([for (var i = 0; i < size * 3; i++) byte() & 0xF0]);
        final search = PaletteSearch(palette);
        for (var q = 0; q < 3000; q++) {
          final r = (byte() & 0xF8).toDouble(), g = (byte() & 0xF8).toDouble(), b = byte() + 0.5;
          expect(search.nearest(r, g, b), nearestIndex(r, g, b, palette));
        }
      });
    }

    test('float centers match nearestCenterIndex', () {
      final centers = Float64List.fromList([for (var i = 0; i < 300 * 3; i++) byte() / 3]);
      final search = PaletteSearch.floats(centers);
      for (var q = 0; q < 2000; q++) {
        final r = byte().toDouble(), g = byte().toDouble(), b = byte().toDouble();
        expect(search.nearest(r, g, b), nearestCenterIndex(r, g, b, centers));
      }
    });
  });
}
