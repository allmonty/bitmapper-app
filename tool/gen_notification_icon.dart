// Generates the Android status-bar notification icon (a simple pixel-grid
// glyph, matching the app's pixel-art branding) at every standard density.
// Android's small-icon guideline requires a flat white-on-transparent
// silhouette -- the app's full-color ic_launcher can't be reused as-is.
// Run from the repo root:
//   dart run tool/gen_notification_icon.dart
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

// 24dp base size, scaled by each density bucket's factor.
const _densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
const _baseSize = 24;

void main() {
  for (final entry in _densities.entries) {
    final size = (_baseSize * entry.value).round();
    final image = img.Image(width: size, height: size, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

    // A 4x4 checkerboard of white blocks in the central ~70% of the
    // canvas -- reads clearly as "pixels" even at 24px.
    const grid = 4;
    final margin = (size * 0.15).round();
    final cell = (size - margin * 2) / grid;
    for (var gy = 0; gy < grid; gy++) {
      for (var gx = 0; gx < grid; gx++) {
        if ((gx + gy).isOdd) continue;
        final x0 = margin + (gx * cell).round();
        final y0 = margin + (gy * cell).round();
        final x1 = margin + ((gx + 1) * cell).round() - 1;
        final y1 = margin + ((gy + 1) * cell).round() - 1;
        img.fillRect(image, x1: x0, y1: y0, x2: x1, y2: y1, color: img.ColorRgba8(255, 255, 255, 255));
      }
    }

    final path = 'android/app/src/main/res/drawable-${entry.key}/ic_stat_export.png';
    File(path).writeAsBytesSync(img.encodePng(image));
    print('wrote $path (${size}x$size)');
  }
}
