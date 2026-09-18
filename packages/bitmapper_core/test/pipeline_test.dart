import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final src = randomImage(40, 30);

  bool isBlocky(RgbImage out, int cols, int rows) {
    final grid = downsample(out, cols, rows, mode: BlockSampling.nearest);
    return upscale(grid, out.width, out.height).data.toString() == out.data.toString();
  }

  group('auto palette', () {
    for (final depth in [2, 4, 8]) {
      for (final method in listDitherMethods()) {
        test('bit depth $depth, $method', () {
          final config = BitmapFilterConfig(
              gridCols: 10, gridRows: 6, bitDepth: depth, dither: method);
          final r = applyBitmapFilter(src, config, outputWidth: 80, outputHeight: 60);
          expect(r.output.width, 80);
          expect(r.output.height, 60);
          expect(r.grid.width, 10);
          expect(r.grid.height, 6);
          expect(colorsOf(r.grid.data).length, lessThanOrEqualTo(1 << depth));
          expect(onlyUsesPalette(r.grid, r.palette), isTrue);
          expect(isBlocky(r.output, 10, 6), isTrue);
        });
      }
    }
  });

  test('output defaults to the source size', () {
    final r = applyBitmapFilter(src, const BitmapFilterConfig(gridCols: 8, gridRows: 6));
    expect(r.output.width, 40);
    expect(r.output.height, 30);
  });

  test('fixed palette is subsampled to the bit depth', () {
    final r = applyBitmapFilter(src,
        const BitmapFilterConfig(
            gridCols: 10, gridRows: 10, paletteMode: PaletteMode.fixed, fixedPalette: 'pico8', bitDepth: 2),
        outputWidth: 20, outputHeight: 20);
    expect(r.paletteSize, 4);
    expect(onlyUsesPalette(r.output, subsample(getPalette('pico8'), 4)), isTrue);
  });

  test('custom palette is honoured', () {
    final r = applyBitmapFilter(src,
        const BitmapFilterConfig(
            gridCols: 10, gridRows: 10, paletteMode: PaletteMode.custom, customPalette: [0xFF0000, 0x0000FF]),
        outputWidth: 20, outputHeight: 20);
    expect(colorsOf(r.output.data).difference({0xFF0000, 0x0000FF}), isEmpty);
  });

  test('true color passes block colors straight through', () {
    const config = BitmapFilterConfig(gridCols: 5, gridRows: 5, bitDepth: 16, dither: 'floyd_steinberg');
    expect(config.isTrueColor, isTrue);
    final r = applyBitmapFilter(src, config);
    expect(r.grid.data, downsample(src, 5, 5).data);
    expect(r.paletteSize, colorsOf(r.grid.data).length);
  });

  test('nearest and average sampling differ', () {
    const base = BitmapFilterConfig(gridCols: 5, gridRows: 5, bitDepth: 16);
    final a = applyBitmapFilter(src, base);
    final n = applyBitmapFilter(src, base.copyWith(blockSampling: BlockSampling.nearest));
    expect(a.grid.data, isNot(n.grid.data));
  });

  test('RGBA input drops alpha', () {
    final rgba = src.toRgba();
    for (var i = 3; i < rgba.length; i += 4) {
      rgba[i] = 7;
    }
    final fromRgba = RgbImage.fromRgba(src.width, src.height, rgba);
    expect(fromRgba.data, src.data);
  });

  test('scanlines and grid gap are applied to the canvas', () {
    final white = solidImage(10, 10, [255, 255, 255]);
    final r = applyBitmapFilter(
        white,
        const BitmapFilterConfig(
            gridCols: 2, gridRows: 2, bitDepth: 16, scanlines: 1.0, gridGapPx: 2, gridGapColor: 0x00FF00));
    expect(r.output.pixel(0, 0), [255, 255, 255]);
    expect(r.output.pixel(0, 1), [0, 0, 0]); // odd row blacked out
    expect(r.output.pixel(4, 0), [0, 255, 0]); // gutter
  });

  test('adjustments run before downsampling', () {
    final r = applyBitmapFilter(solidImage(4, 4, [200, 50, 10]),
        const BitmapFilterConfig(gridCols: 1, gridRows: 1, bitDepth: 16, saturation: 0));
    final p = r.grid.pixel(0, 0);
    expect(p[0], p[1]);
    expect(p[1], p[2]);
  });

  test('cancellation aborts the run', () {
    expect(
      () => applyBitmapFilter(src, const BitmapFilterConfig(gridCols: 10, gridRows: 10),
          isCancelled: () => true),
      throwsA(isA<FilterCancelled>()),
    );
  });

  group('config validation', () {
    final invalid = <String, BitmapFilterConfig>{
      'bitDepth 0': const BitmapFilterConfig(bitDepth: 0),
      'bitDepth 25': const BitmapFilterConfig(bitDepth: 25),
      'grid 0': const BitmapFilterConfig(gridCols: 0),
      'unknown algorithm': const BitmapFilterConfig(paletteAlgorithm: 'nope'),
      'unknown dither': const BitmapFilterConfig(dither: 'nope'),
      'negative dither strength': const BitmapFilterConfig(ditherStrength: -0.1),
      'scanlines > 1': const BitmapFilterConfig(scanlines: 1.1),
      'scanlines < 0': const BitmapFilterConfig(scanlines: -0.1),
      'negative gap': const BitmapFilterConfig(gridGapPx: -1),
      'negative contrast': const BitmapFilterConfig(contrast: -1),
      'negative saturation': const BitmapFilterConfig(saturation: -1),
      'zero gamma': const BitmapFilterConfig(gamma: 0),
      'fixed without name': const BitmapFilterConfig(paletteMode: PaletteMode.fixed),
      'custom without colors': const BitmapFilterConfig(paletteMode: PaletteMode.custom),
      'custom empty': const BitmapFilterConfig(paletteMode: PaletteMode.custom, customPalette: []),
    };
    for (final e in invalid.entries) {
      test('rejects ${e.key}', () {
        expect(e.value.validate, throwsArgumentError);
        expect(() => applyBitmapFilter(src, e.value), throwsArgumentError);
      });
    }

    test('defaults are valid and match the Python reference', () {
      const d = BitmapFilterConfig();
      d.validate();
      expect(d.gridCols, 200);
      expect(d.bitDepth, 8);
      expect(d.nColors, 256);
      expect(d.dither, 'none');
    });

    test('unknown fixed palette name fails at run time', () {
      expect(
          () => applyBitmapFilter(src,
              const BitmapFilterConfig(paletteMode: PaletteMode.fixed, fixedPalette: 'nope')),
          throwsArgumentError);
    });
  });

  group('config json', () {
    test('round-trips every field', () {
      const config = BitmapFilterConfig(
        gridCols: 33,
        gridRows: 21,
        bitDepth: 3,
        blockSampling: BlockSampling.nearest,
        paletteMode: PaletteMode.custom,
        paletteAlgorithm: 'kmeans',
        fixedPalette: 'nes',
        customPalette: [1, 2, 3],
        dither: 'stucki',
        ditherStrength: 0.25,
        scanlines: 0.5,
        gridGapPx: 3,
        gridGapColor: 0x123456,
        contrast: 1.2,
        saturation: 0.8,
        gamma: 1.7,
        randomSeed: 42,
      );
      expect(BitmapFilterConfig.fromJson(config.toJson()), config);
    });

    test('missing keys fall back to defaults', () {
      expect(BitmapFilterConfig.fromJson({}), const BitmapFilterConfig());
    });

    test('copyWith and equality', () {
      const a = BitmapFilterConfig();
      expect(a.copyWith(bitDepth: 4), isNot(a));
      expect(a.copyWith(bitDepth: 4), a.copyWith(bitDepth: 4));
      expect(a.copyWith(bitDepth: 4).hashCode, a.copyWith(bitDepth: 4).hashCode);
    });
  });
}
