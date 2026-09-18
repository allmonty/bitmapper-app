import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('lists the eight Python presets, sorted', () {
    expect(listPresets(), [
      'arcade_cabinet', 'crt_terminal', 'gameboy_camera', 'newspaper', //
      'pico8_game', 'sepia_photo', 'vaporwave', 'vhs',
    ]);
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
}
