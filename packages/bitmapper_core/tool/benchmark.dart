// Rough timing of the full pipeline, mirroring the Python scripts/benchmark.py.
// Run AOT for realistic numbers:
//   dart compile exe tool/benchmark.dart -o /tmp/bench && /tmp/bench
import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';

void main() {
  final rng = XorShift128Plus(0);
  final data = Uint8List(1200 * 1200 * 3);
  for (var i = 0; i < data.length; i++) {
    data[i] = rng.nextInt64() & 0xFF;
  }
  final src = RgbImage(1200, 1200, data);
  for (final method in listDitherMethods()) {
    final config = BitmapFilterConfig(gridCols: 150, gridRows: 150, bitDepth: 4, dither: method);
    final sw = Stopwatch()..start();
    applyBitmapFilter(src, config);
    print('${method.padRight(22)} ${sw.elapsedMilliseconds} ms');
  }
}
