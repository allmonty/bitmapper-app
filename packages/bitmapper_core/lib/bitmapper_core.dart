/// Retro pixel-art ("bitmap") image filter: a pure-Dart port of the Python
/// `bitmapper` reference implementation. No Flutter dependency, so it runs
/// in `Isolate.run` and tests with plain `dart test`.
library;

export 'src/adjustments.dart';
export 'src/config.dart';
export 'src/dither.dart';
export 'src/effects.dart';
export 'src/grid.dart';
export 'src/image.dart';
export 'src/outline.dart';
export 'src/palette_gen.dart';
export 'src/palettes.dart';
export 'src/pipeline.dart';
export 'src/presets.dart';
export 'src/prng.dart';
export 'src/quantize.dart';
export 'src/sequence.dart';
export 'src/toon.dart';
