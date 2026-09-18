import 'config.dart';

/// Built-in looks, ported from the Python `presets.py`. They set only "look"
/// fields; grid size stays at the config default (callers override it).
const Map<String, BitmapFilterConfig> kBuiltInPresets = {
  'arcade_cabinet': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'cga',
    bitDepth: 2,
    dither: 'floyd_steinberg',
    scanlines: 0.35,
    gridGapPx: 1,
  ),
  'crt_terminal': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'monochrome_green',
    bitDepth: 2,
    dither: 'ordered',
    scanlines: 0.4,
  ),
  'gameboy_camera': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'gameboy',
    bitDepth: 2,
    dither: 'ordered',
  ),
  'newspaper': BitmapFilterConfig(
    paletteMode: PaletteMode.custom,
    customPalette: [0x000000, 0xFFFFFF],
    dither: 'ordered',
    saturation: 0.0,
    contrast: 1.3,
  ),
  'pico8_game': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'pico8',
    bitDepth: 4,
    dither: 'none',
    gridGapPx: 1,
  ),
  'sepia_photo': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'sepia',
    bitDepth: 5,
    dither: 'floyd_steinberg',
    contrast: 1.1,
  ),
  'vaporwave': BitmapFilterConfig(
    paletteMode: PaletteMode.custom,
    customPalette: [0x09032E, 0xFF69B4, 0x00FFFF, 0xFFFDD0],
    dither: 'floyd_steinberg',
    saturation: 1.4,
    gamma: 1.2,
  ),
  'vhs': BitmapFilterConfig(
    paletteMode: PaletteMode.auto,
    bitDepth: 5,
    dither: 'floyd_steinberg',
    ditherStrength: 0.6,
    saturation: 1.3,
    contrast: 0.9,
    scanlines: 0.25,
  ),
};

/// Built-in preset names, sorted.
List<String> listPresets() => kBuiltInPresets.keys.toList()..sort();

/// The named preset. Callers override fields (e.g. grid size) with
/// `copyWith`.
BitmapFilterConfig getPreset(String name) {
  final preset = kBuiltInPresets[name];
  if (preset == null) {
    throw ArgumentError('unknown preset "$name", available: ${listPresets()}');
  }
  return preset;
}
