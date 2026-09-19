import 'config.dart';

/// Built-in looks, ported from the Python `presets.py`. They set only "look"
/// fields; grid size stays at the config default (callers override it, e.g.
/// with [presetColumns]).
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
  // Pixel-art looks: flat colors (no dithering), curated pixel-art palettes,
  // a little extra punch, and a suggested chunky grid (kPresetColumns).
  'pixel_art': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'pico8',
    bitDepth: 4,
    dither: 'none',
    contrast: 1.15,
    saturation: 1.25,
  ),
  'pixel_art_earthy': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'db16',
    bitDepth: 4,
    dither: 'none',
    contrast: 1.1,
  ),
  'pixel_art_mono': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'gameboy',
    bitDepth: 2,
    dither: 'none',
    contrast: 1.3,
  ),
  'pixel_art_rich': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'endesga32',
    bitDepth: 5,
    dither: 'none',
    contrast: 1.1,
    saturation: 1.15,
  ),
  'pixel_art_soft': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'sweetie16',
    bitDepth: 4,
    dither: 'none',
    saturation: 1.1,
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
  'amstrad_cpc': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'amstrad_cpc',
    bitDepth: 5,
    dither: 'floyd_steinberg',
    scanlines: 0.2,
  ),
  // Bill Atkinson's dither was the Mac's own.
  'classic_mac': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'mac16',
    bitDepth: 4,
    dither: 'atkinson',
  ),
  'comic_halftone': BitmapFilterConfig(
    paletteMode: PaletteMode.custom,
    customPalette: [0xFFFFFF, 0x00FFFF, 0xFF00FF, 0xFFFF00, 0x000000],
    dither: 'clustered_dot',
    ditherStrength: 0.5,
    saturation: 1.3,
    gamma: 1.2,
  ),
  'dawnbringer': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'db16',
    bitDepth: 4,
    dither: 'floyd_steinberg_serpentine',
  ),
  'endesga_art': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'endesga32',
    bitDepth: 5,
    dither: 'interleaved_gradient_noise',
    saturation: 1.1,
  ),
  'gameboy_pocket': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'gameboy_pocket',
    bitDepth: 2,
    dither: 'ordered',
  ),
  'macpaint': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'one_bit',
    bitDepth: 1,
    dither: 'atkinson',
    contrast: 1.1,
  ),
  'master_system': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'master_system',
    bitDepth: 6,
    dither: 'sierra_lite',
  ),
  'tic80': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'sweetie16',
    bitDepth: 4,
    dither: 'interleaved_gradient_noise',
  ),
  'virtual_boy': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'virtualboy',
    bitDepth: 2,
    dither: 'ordered',
    saturation: 0.0,
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
  'windows98': BitmapFilterConfig(
    paletteMode: PaletteMode.fixed,
    fixedPalette: 'windows16',
    bitDepth: 4,
    dither: 'ordered',
  ),
};

/// Grid width (columns) a preset is designed for. Rows depend on the image's
/// aspect ratio, so presets suggest columns instead of fixing the grid.
const Map<String, int> kPresetColumns = {
  'pixel_art': 64,
  'pixel_art_soft': 64,
  'pixel_art_rich': 80,
  'pixel_art_earthy': 64,
  'pixel_art_mono': 48,
};

/// The grid width preset `name` is designed for, or null if it works at any
/// grid size.
int? presetColumns(String name) {
  if (!kBuiltInPresets.containsKey(name)) {
    throw ArgumentError('unknown preset "$name", available: ${listPresets()}');
  }
  return kPresetColumns[name];
}

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
