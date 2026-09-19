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
  'sierra_two_row': 'Sierra Two-Row',
  'false_floyd_steinberg': 'False Floyd–Steinberg',
  'simple': 'Simple (row only)',
  'floyd_steinberg_serpentine': 'Floyd–Steinberg serpentine',
  'ordered_16x16': 'Ordered (Bayer 16×16)',
  'clustered_dot': 'Clustered dot (halftone)',
  'interleaved_gradient_noise': 'Gradient noise (blue-ish)',
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
  'amstrad_cpc': 'Amstrad CPC',
  'cga_palette0': 'CGA (palette 0)',
  'db16': 'DawnBringer 16',
  'endesga32': 'Endesga 32',
  'gameboy_pocket': 'Game Boy Pocket',
  'grayscale16': 'Grayscale 16',
  'mac16': 'Classic Mac',
  'master_system': 'Master System',
  'one_bit': '1-bit',
  'sweetie16': 'Sweetie 16',
  'thermal': 'Thermal',
  'virtualboy': 'Virtual Boy',
  'windows16': 'Windows 16',
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
  'amstrad_cpc': 'Amstrad CPC',
  'classic_mac': 'Classic Mac',
  'comic_halftone': 'Comic Halftone',
  'dawnbringer': 'DawnBringer',
  'endesga_art': 'Endesga Art',
  'gameboy_pocket': 'Game Boy Pocket',
  'macpaint': 'MacPaint',
  'master_system': 'Master System',
  'tic80': 'TIC-80',
  'virtual_boy': 'Virtual Boy',
  'windows98': 'Windows 98',
  'pixel_art': 'Pixel Art',
  'pixel_art_soft': 'Pixel Art Soft',
  'pixel_art_rich': 'Pixel Art Rich',
  'pixel_art_earthy': 'Pixel Art Earthy',
  'pixel_art_mono': 'Pixel Art Mono',
  'pixel_art_sprite': 'Pixel Art Sprite',
  'toon': 'Toon',
  'toon_pastel': 'Toon Pastel',
};

const kOutlineMethodLabels = <String, String>{
  'brightness': 'Brightness',
  'color': 'Color',
  'sobel': 'Sobel (best for photos)',
};

const kOutlineInkLabels = <String, String>{'darkest': 'Darkest color', 'shaded': 'Shaded'};

String ditherLabel(String id) => kDitherLabels[id] ?? id;
String paletteLabel(String id) => kPaletteLabels[id] ?? id;
String outlineMethodLabel(String id) => kOutlineMethodLabels[id] ?? id;
String outlineInkLabel(String id) => kOutlineInkLabels[id] ?? id;
