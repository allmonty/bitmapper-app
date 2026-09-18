import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:test/test.dart';

void main() {
  const expectedSizes = {
    'cga': 4,
    'ega': 16,
    'gameboy': 4,
    'vga256': 256,
    'c64': 16,
    'zxspectrum': 16,
    'pico8': 16,
    'nes': 64,
    'appleii': 16,
    'msx': 16,
    'teletext': 8,
    'monochrome_green': 4,
    'monochrome_amber': 4,
    'sepia': 32,
  };

  test('lists every palette, sorted', () {
    expect(listPalettes(), expectedSizes.keys.toList()..sort());
  });

  for (final entry in expectedSizes.entries) {
    test('${entry.key} has ${entry.value} colors', () {
      expect(paletteLength(getPalette(entry.key)), entry.value);
    });
  }

  test('generated data matches spot values from the Python reference', () {
    expect(getPalette('cga'), [0, 0, 0, 85, 255, 255, 255, 85, 255, 255, 255, 255]);
    final vga = getPalette('vga256');
    expect(vga.sublist(0, 6), [0, 0, 0, 0, 0, 51]); // cube, b-minor
    expect(vga.sublist(215 * 3, 216 * 3), [255, 255, 255]);
    expect(vga.sublist(216 * 3, 218 * 3), [0, 0, 0, 6, 6, 6]); // gray ramp
  });

  test('getPalette returns a copy', () {
    final a = getPalette('cga');
    a[0] = 99;
    expect(getPalette('cga')[0], 0);
  });

  test('unknown palette throws', () {
    expect(() => getPalette('nope'), throwsArgumentError);
  });

  group('subsample', () {
    test('matches the Python reference', () {
      expect(subsample(getPalette('ega'), 4), [0, 0, 0, 170, 0, 170, 85, 255, 85, 255, 255, 255]);
      expect(subsample(getPalette('nes'), 8), [
        124, 124, 124, 0, 120, 0, 0, 88, 248, 0, 168, 68, //
        248, 120, 248, 120, 120, 120, 240, 208, 176, 0, 0, 0,
      ]);
    });

    test('keeps first and last', () {
      final pal = getPalette('pico8');
      final sub = subsample(pal, 3);
      expect(sub.sublist(0, 3), pal.sublist(0, 3));
      expect(sub.sublist(6, 9), pal.sublist(pal.length - 3));
    });

    test('returns a copy when already small enough', () {
      final pal = getPalette('cga');
      final sub = subsample(pal, 16);
      expect(sub, pal);
      expect(identical(sub, pal), isFalse);
    });

    test('rejects n < 1', () {
      expect(() => subsample(getPalette('cga'), 0), throwsArgumentError);
    });
  });

  group('roundHalfEven (NumPy rounding)', () {
    test('rounds exact halves to even', () {
      expect(roundHalfEven(0.5), 0);
      expect(roundHalfEven(1.5), 2);
      expect(roundHalfEven(2.5), 2);
      expect(roundHalfEven(3.5), 4);
    });
    test('rounds other values normally', () {
      expect(roundHalfEven(2.49), 2);
      expect(roundHalfEven(2.51), 3);
    });
    test('linspaceIndices differs from naive rounding at halves', () {
      // linspace(0, 5, 3) = [0, 2.5, 5] -> NumPy picks index 2, not 3.
      expect(linspaceIndices(6, 3), [0, 2, 5]);
      expect(subsample(Uint8List.fromList(List.generate(18, (i) => i)), 3),
          [0, 1, 2, 6, 7, 8, 15, 16, 17]);
    });
  });
}
