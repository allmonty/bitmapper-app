import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  // A short "animation": the same scene with its brightness drifting, so
  // per-frame palettes differ.
  List<RgbImage> frames(int n) => [
        for (var f = 0; f < n; f++)
          RgbImage(24, 18, Uint8List.fromList([
            for (final v in randomImage(24, 18, seed: 5).data) (v * (0.5 + f / (2 * n))).toInt(),
          ])),
      ];

  const base = BitmapFilterConfig(gridCols: 12, gridRows: 9, bitDepth: 3, dither: 'floyd_steinberg');

  group('sampleIndices', () {
    test('spreads samples and keeps first and last', () {
      expect(sampleIndices(100, 5), [0, 24, 49, 74, 99]);
      expect(sampleIndices(10, 2), [0, 9]);
    });
    test('handles small counts', () {
      expect(sampleIndices(0, 4), isEmpty);
      expect(sampleIndices(1, 8), [0]);
      expect(sampleIndices(3, 8), [0, 1, 2]);
      expect(sampleIndices(10, 1), [0]);
    });
  });

  group('paletteSourceFrames', () {
    test('per strategy', () {
      expect(paletteSourceFrames(base.copyWith(paletteStrategy: PaletteStrategy.perFrame), 20), isEmpty);
      expect(paletteSourceFrames(base.copyWith(paletteStrategy: PaletteStrategy.firstFrame), 20), [0]);
      expect(
        paletteSourceFrames(base.copyWith(paletteStrategy: PaletteStrategy.sampled, paletteSamples: 3), 21),
        [0, 10, 20],
      );
    });
    test('none needed for fixed palettes or true color', () {
      expect(paletteSourceFrames(base.copyWith(paletteMode: PaletteMode.fixed, fixedPalette: 'cga'), 20), isEmpty);
      expect(paletteSourceFrames(base.copyWith(bitDepth: 24), 20), isEmpty);
    });
  });

  for (final strategy in [PaletteStrategy.firstFrame, PaletteStrategy.sampled]) {
    test('$strategy: one palette, every frame uses only its colors', () {
      final clip = frames(6);
      final config = base.copyWith(paletteStrategy: strategy, paletteSamples: 3);
      final sources = [for (final i in paletteSourceFrames(config, clip.length)) clip[i]];
      final palette = sequencePalette(sources, config)!;
      expect(palette.length, config.nColors * 3);
      for (final frame in clip) {
        final r = applyBitmapFilter(frame, config, palette: palette);
        expect(r.palette, palette);
        expect(onlyUsesPalette(r.grid, palette), isTrue);
      }
    });
  }

  test('firstFrame palette equals the palette of a still run on frame 0', () {
    final clip = frames(4);
    final config = base.copyWith(paletteStrategy: PaletteStrategy.firstFrame);
    expect(sequencePalette([clip.first], config), applyBitmapFilter(clip.first, config).palette);
  });

  test('perFrame: no shared palette, frames match independent runs', () {
    final clip = frames(4);
    final config = base.copyWith(paletteStrategy: PaletteStrategy.perFrame);
    expect(sequencePalette(clip, config), isNull);
    final palettes = {for (final f in clip) applyBitmapFilter(f, config).palette.toString()};
    expect(palettes.length, greaterThan(1), reason: 'the drifting frames get different palettes');
  });

  test('sequencePalette is null for fixed palettes and true color', () {
    final clip = frames(2);
    expect(sequencePalette(clip, base.copyWith(paletteMode: PaletteMode.fixed, fixedPalette: 'cga')), isNull);
    expect(sequencePalette(clip, base.copyWith(bitDepth: 16)), isNull);
    expect(sequencePalette(const [], base), isNull);
  });

  group('random noise', () {
    final frame = randomImage(20, 20, seed: 8);
    final config = base.copyWith(dither: 'random', randomSeed: 3);

    test('static by default: same frame, same noise', () {
      expect(frameSeed(config, 0), frameSeed(config, 5));
      final a = applyBitmapFilter(frame, config, seed: frameSeed(config, 0));
      final b = applyBitmapFilter(frame, config, seed: frameSeed(config, 5));
      expect(a.grid.data, b.grid.data);
    });

    test('animated noise varies per frame', () {
      final animated = config.copyWith(animateNoise: true);
      expect(frameSeed(animated, 0), isNot(frameSeed(animated, 1)));
      final a = applyBitmapFilter(frame, animated, seed: frameSeed(animated, 0));
      final b = applyBitmapFilter(frame, animated, seed: frameSeed(animated, 1));
      expect(a.grid.data, isNot(b.grid.data));
    });
  });

  group('config', () {
    test('sequence fields default for stills and round-trip through JSON', () {
      const d = BitmapFilterConfig();
      expect(d.paletteStrategy, PaletteStrategy.sampled);
      expect(d.paletteSamples, 8);
      expect(d.animateNoise, isFalse);
      final c = d.copyWith(paletteStrategy: PaletteStrategy.firstFrame, paletteSamples: 5, animateNoise: true);
      expect(BitmapFilterConfig.fromJson(c.toJson()), c);
      expect(c, isNot(d));
    });

    test('rejects out-of-range sample counts', () {
      expect(const BitmapFilterConfig(paletteSamples: 1).validate, throwsArgumentError);
      expect(const BitmapFilterConfig(paletteSamples: 33).validate, throwsArgumentError);
    });
  });
}
