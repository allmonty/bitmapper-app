import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('lists the Python presets, sorted', () {
    expect(listPresets(), [
      'amstrad_cpc', 'arcade_cabinet', 'classic_mac', 'comic_halftone', 'crt_terminal', //
      'dawnbringer', 'endesga_art', 'gameboy_camera', 'gameboy_pocket', 'macpaint',
      'master_system', 'newspaper', 'pico8_game', 'pixel_art', 'pixel_art_earthy',
      'pixel_art_mono', 'pixel_art_rich', 'pixel_art_soft', 'pixel_art_sprite', 'sepia_photo',
      'tic80', 'toon', 'toon_pastel',
      'vaporwave', 'vhs', 'virtual_boy', 'windows98',
    ]);
  });

  test('every preset uses palettes and dithers that exist', () {
    for (final name in listPresets()) {
      final p = getPreset(name);
      expect(listDitherMethods(), contains(p.dither), reason: name);
      if (p.fixedPalette != null) expect(listPalettes(), contains(p.fixedPalette), reason: name);
    }
  });

  for (final name in listPresets()) {
    test('$name is valid and runs through the pipeline', () {
      final config = getPreset(name).copyWith(gridCols: 12, gridRows: 9);
      config.validate();
      final r = applyBitmapFilter(randomImage(24, 18), config);
      expect(r.output.width, 24);
      expect(r.grid.width, 12);
    });
  }

  test('preset values match the Python reference', () {
    final vhs = getPreset('vhs');
    expect(vhs.bitDepth, 5);
    expect(vhs.ditherStrength, 0.6);
    expect(vhs.saturation, 1.3);
    expect(vhs.contrast, 0.9);
    expect(vhs.scanlines, 0.25);
    final arcade = getPreset('arcade_cabinet');
    expect(arcade.fixedPalette, 'cga');
    expect(arcade.gridGapPx, 1);
    expect(getPreset('newspaper').customPalette, [0x000000, 0xFFFFFF]);
    expect(getPreset('newspaper').bitDepth, 8);
  });

  test('unknown preset throws', () {
    expect(() => getPreset('nope'), throwsArgumentError);
  });

  group('pixel-art presets', () {
    const pixelArt = [
      'pixel_art',
      'pixel_art_soft',
      'pixel_art_rich',
      'pixel_art_earthy',
      'pixel_art_mono',
      'pixel_art_sprite',
    ];

    for (final name in pixelArt) {
      test('$name: flat colors, a fixed palette and a chunky suggested grid', () {
        final p = getPreset(name);
        expect(p.dither, 'none');
        expect(p.paletteMode, PaletteMode.fixed);
        final cols = presetColumns(name)!;
        expect(cols, inInclusiveRange(32, 96));

        // At its suggested grid the output uses only palette colors.
        final r = applyBitmapFilter(
          randomImage(cols * 2, cols * 2),
          p.copyWith(gridCols: cols, gridRows: cols),
        );
        expect(onlyUsesPalette(r.grid, r.palette), isTrue);
      });
    }

    test('columns match the Python reference', () {
      expect(kPresetColumns, {
        'pixel_art': 64,
        'pixel_art_soft': 64,
        'pixel_art_rich': 80,
        'pixel_art_earthy': 64,
        'pixel_art_mono': 48,
        'pixel_art_sprite': 64,
        'toon': 96,
        'toon_pastel': 96,
      });
    });

    test('presets without a suggestion return null; unknown names throw', () {
      expect(presetColumns('vhs'), isNull);
      expect(() => presetColumns('nope'), throwsArgumentError);
    });
  });
}
