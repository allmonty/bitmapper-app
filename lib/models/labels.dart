/// Display names for engine identifiers. These are proper names (palettes,
/// algorithms, looks), so they are not translated.
library;

const kDitherLabels = <String, String>{
  'none': 'None',
  'floyd_steinberg': 'Floyd–Steinberg',
  'atkinson': 'Atkinson',
  'jarvis_judice_ninke': 'Jarvis–Judice–Ninke',
  'stucki': 'Stucki',
  'sierra': 'Sierra',
  'sierra_lite': 'Sierra Lite',
  'burkes': 'Burkes',
  'ordered_2x2': 'Ordered (Bayer 2×2)',
  'ordered': 'Ordered (Bayer 4×4)',
  'ordered_8x8': 'Ordered (Bayer 8×8)',
  'random': 'Random noise',
};

const kPaletteLabels = <String, String>{
  'appleii': 'Apple II',
  'c64': 'Commodore 64',
  'cga': 'CGA',
  'ega': 'EGA',
  'gameboy': 'Game Boy',
  'monochrome_amber': 'Amber phosphor',
  'monochrome_green': 'Green phosphor',
  'msx': 'MSX',
  'nes': 'NES',
  'pico8': 'PICO-8',
  'sepia': 'Sepia',
  'teletext': 'Teletext',
  'vga256': 'VGA 256',
  'zxspectrum': 'ZX Spectrum',
};

const kPresetLabels = <String, String>{
  'arcade_cabinet': 'Arcade Cabinet',
  'crt_terminal': 'CRT Terminal',
  'gameboy_camera': 'Game Boy Camera',
  'newspaper': 'Newspaper',
  'pico8_game': 'PICO-8 Game',
  'sepia_photo': 'Sepia Photo',
  'vaporwave': 'Vaporwave',
  'vhs': 'VHS',
};

String ditherLabel(String id) => kDitherLabels[id] ?? id;
String paletteLabel(String id) => kPaletteLabels[id] ?? id;
