import 'package:bitmapper/models/editor_model.dart';
import 'package:bitmapper/models/presets_model.dart';
import 'package:bitmapper/models/preset.dart';
import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late EditorModel model;
  late int notifications;

  setUp(() {
    model = EditorModel();
    notifications = 0;
    model.addListener(() => notifications++);
  });

  test('starts from the default config', () {
    expect(model.config, kDefaultConfig);
    expect(model.columns, 120);
    expect(model.trueColor, isFalse);
  });

  group('rowsFor / configFor', () {
    test('keeps cells square', () {
      expect(rowsFor(120, 400, 300), 90);
      expect(rowsFor(100, 300, 400), 133);
      expect(rowsFor(10, 1000, 1), 1);
    });

    test('clamps columns to the image width', () {
      final c = model.configFor(64, 48);
      expect(c.gridCols, 64);
      expect(c.gridRows, 48);
    });

    test('keeps the rest of the config', () {
      model.setDither('atkinson');
      expect(model.configFor(400, 300).dither, 'atkinson');
    });
  });

  test('setters update config and notify once', () {
    model.setDither('stucki');
    model.setDitherStrength(0.5);
    model.setContrast(1.5);
    model.setSaturation(0.2);
    model.setGamma(2);
    model.setScanlines(0.3);
    model.setGridGap(2);
    model.setGridGapColor(0xFF123456);
    model.setBlockSampling(BlockSampling.nearest);
    model.setPaletteAlgorithm('kmeans');
    final c = model.config;
    expect(c.dither, 'stucki');
    expect(c.ditherStrength, 0.5);
    expect(c.contrast, 1.5);
    expect(c.saturation, 0.2);
    expect(c.gamma, 2);
    expect(c.scanlines, 0.3);
    expect(c.gridGapPx, 2);
    expect(c.gridGapColor, 0x123456);
    expect(c.blockSampling, BlockSampling.nearest);
    expect(c.paletteAlgorithm, 'kmeans');
    expect(notifications, 10);
  });

  test('outline setter and validation', () {
    model.setOutline(0.4);
    expect(model.config.outline, 0.4);
    expect(() => model.setOutline(1.5), throwsArgumentError);
    expect(model.config.outline, 0.4);
  });

  test('outline method and ink setters and validation', () {
    expect(model.config.outlineMethod, 'brightness');
    expect(model.config.outlineInk, 'darkest');
    model.setOutlineMethod('sobel');
    model.setOutlineInk('shaded');
    expect(model.config.outlineMethod, 'sobel');
    expect(model.config.outlineInk, 'shaded');
    expect(() => model.setOutlineMethod('nonsense'), throwsArgumentError);
    expect(() => model.setOutlineInk('nonsense'), throwsArgumentError);
    expect(model.config.outlineMethod, 'sobel');
    expect(model.config.outlineInk, 'shaded');
  });

  test('toon setters and validation', () {
    model.setShadeBands(3);
    model.setDespeckle(true);
    expect((model.config.shadeBands, model.config.despeckle), (3, true));
    expect(() => model.setShadeBands(1), throwsArgumentError);
    expect(model.config.shadeBands, 3);
    model.setShadeBands(0);
    expect(model.config.shadeBands, 0);
  });

  test('Toon applies bands, cleanup, outline and 96 columns', () {
    final toon = PresetsModel.builtIns.firstWhere((p) => p.id == 'builtin:toon');
    model.applyPreset(toon);
    expect(model.config.shadeBands, 3);
    expect(model.config.despeckle, isTrue);
    expect(model.config.outline, 0.5);
    expect(model.columns, 96);
  });

  test('Pixel Art Sprite applies its outline and columns', () {
    final sprite = PresetsModel.builtIns.firstWhere((p) => p.id == 'builtin:pixel_art_sprite');
    model.applyPreset(sprite);
    expect(model.config.outline, 0.4);
    expect(model.columns, 64);
  });

  test('setting the same value does not notify', () {
    model.setDither(model.config.dither);
    expect(notifications, 0);
  });

  test('columns are clamped to the supported range', () {
    model.setColumns(5);
    expect(model.columns, kMinColumns);
    model.setColumns(10000);
    expect(model.columns, kMaxColumns);
  });

  test('invalid values throw and leave the config untouched', () {
    expect(() => model.setGamma(0), throwsArgumentError);
    expect(() => model.setScanlines(2), throwsArgumentError);
    expect(model.config, kDefaultConfig);
  });

  group('palette mode', () {
    test('fixed mode picks a default palette', () {
      model.setPaletteMode(PaletteMode.fixed);
      expect(model.config.paletteMode, PaletteMode.fixed);
      expect(model.config.fixedPalette, 'pico8');
    });

    test('custom mode seeds black and white', () {
      model.setPaletteMode(PaletteMode.custom);
      expect(model.config.customPalette, kDefaultCustomPalette);
    });

    test('custom palette updates, ignoring an empty list', () {
      model.setPaletteMode(PaletteMode.custom);
      model.setCustomPalette([0xFF0000]);
      expect(model.config.customPalette, [0xFF0000]);
      model.setCustomPalette([]);
      expect(model.config.customPalette, [0xFF0000]);
    });

    test('true color toggles to 24 bits and back to the previous depth', () {
      model.setBitDepth(3);
      model.setTrueColor(true);
      expect(model.trueColor, isTrue);
      expect(model.config.bitDepth, kTrueColorBitDepth);
      expect(model.config.isTrueColor, isTrue);
      model.setTrueColor(false);
      expect(model.config.bitDepth, 3);
    });

    test('auto mode goes up to 12 bits, then true color', () {
      expect(model.maxBitDepth, 12);
      model.setBitDepth(12);
      expect(model.config.bitDepth, 12);
      expect(model.config.nColors, 4096);
      expect(model.trueColor, isFalse);
      model.setBitDepth(kTrueColorStop);
      expect(model.trueColor, isTrue);
      model.setBitDepth(10);
      expect(model.trueColor, isFalse);
      expect(model.config.bitDepth, 10);
    });

    test('fixed and custom palettes cap at 8 bits', () {
      model.setBitDepth(11);
      model.setPaletteMode(PaletteMode.fixed);
      expect(model.maxBitDepth, 8);
      expect(model.config.bitDepth, 8);
      model.setBitDepth(kTrueColorStop);
      expect(model.config.bitDepth, 8);
      expect(model.trueColor, isFalse);
      model.setPaletteMode(PaletteMode.custom);
      expect(model.config.bitDepth, 8);
    });

    test('leaving auto mode drops true color', () {
      model.setBitDepth(5);
      model.setTrueColor(true);
      model.setPaletteMode(PaletteMode.fixed);
      expect(model.config.bitDepth, 5);
    });
  });

  group('presets', () {
    test('built-in presets keep the current column count', () {
      model.setColumns(64);
      final vhs = PresetsModel.builtIns.firstWhere((p) => p.id == 'builtin:vhs');
      model.applyPreset(vhs);
      expect(model.columns, 64);
      expect(model.config.dither, 'floyd_steinberg');
      expect(model.config.bitDepth, 5);
      expect(model.config.scanlines, 0.25);
    });

    test('pixel-art presets set their suggested columns', () {
      model.setColumns(200);
      final pixelArt = PresetsModel.builtIns.firstWhere((p) => p.id == 'builtin:pixel_art');
      expect(pixelArt.columns, 64);
      model.applyPreset(pixelArt);
      expect(model.columns, 64);
      expect(model.config.dither, 'none');
      expect(model.config.fixedPalette, 'pico8');
      // Still adjustable afterwards.
      model.setColumns(90);
      expect(model.columns, 90);
      // Presets without a suggestion keep the current count.
      model.applyPreset(PresetsModel.builtIns.firstWhere((p) => p.id == 'builtin:vhs'));
      expect(model.columns, 90);
    });

    test('user presets restore everything, including columns', () {
      final preset = AppPreset(
        id: 'user:1',
        name: 'Mine',
        config: kDefaultConfig.copyWith(gridCols: 42, dither: 'burkes'),
      );
      model.applyPreset(preset);
      expect(model.config, preset.config);
    });
  });

  test('resetAdjustments and reset', () {
    model.setContrast(2);
    model.setGamma(0.5);
    model.setDither('atkinson');
    model.resetAdjustments();
    expect(model.config.contrast, 1);
    expect(model.config.gamma, 1);
    expect(model.config.dither, 'atkinson');
    model.reset();
    expect(model.config, kDefaultConfig);
  });
}
