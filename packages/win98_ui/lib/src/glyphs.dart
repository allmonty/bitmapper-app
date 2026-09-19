import 'package:flutter/widgets.dart';

/// A 1-bit pixel-art glyph: each string is a row, `#` is a lit pixel.
///
/// Win98's arrows, checkmarks and caption-button symbols were tiny bitmaps;
/// drawing them the same way keeps them crisp at any scale.
class PixelGlyph extends StatelessWidget {
  const PixelGlyph(this.pattern, {super.key, this.color, this.pixelSize = 2});

  final List<String> pattern;
  final Color? color;

  /// Logical size of one glyph pixel.
  final double pixelSize;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
    final cols = pattern.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    return CustomPaint(
      size: Size(cols * pixelSize, pattern.length * pixelSize),
      painter: _PixelGlyphPainter(pattern, c, pixelSize),
    );
  }
}

class _PixelGlyphPainter extends CustomPainter {
  _PixelGlyphPainter(this.pattern, this.color, this.pixelSize);

  final List<String> pattern;
  final Color color;
  final double pixelSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 0; y < pattern.length; y++) {
      final row = pattern[y];
      for (var x = 0; x < row.length; x++) {
        if (row.codeUnitAt(x) == 0x23 /* # */ ) {
          canvas.drawRect(Rect.fromLTWH(x * pixelSize, y * pixelSize, pixelSize, pixelSize), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PixelGlyphPainter old) =>
      old.color != color || old.pixelSize != pixelSize || old.pattern != pattern;
}

/// The stock glyph bitmaps.
abstract final class Win98Glyphs {
  static const close = [
    '##....##',
    '.##..##.',
    '..####..',
    '...##...',
    '..####..',
    '.##..##.',
    '##....##',
  ];
  static const minimize = [
    '........',
    '........',
    '........',
    '........',
    '........',
    '######..',
    '######..',
  ];
  static const maximize = [
    '#########',
    '#########',
    '#.......#',
    '#.......#',
    '#.......#',
    '#.......#',
    '#########',
  ];
  static const arrowDown = ['#######', '.#####.', '..###..', '...#...'];
  static const arrowUp = ['...#...', '..###..', '.#####.', '#######'];
  static const arrowRight = ['#...', '##..', '###.', '####', '###.', '##..', '#...'];
  static const arrowLeft = ['...#', '..##', '.###', '####', '.###', '..##', '...#'];
  static const check = [
    '......#',
    '.....##',
    '#...###',
    '##.###.',
    '#####..',
    '.###...',
    '..#....',
  ];
  static const dot = ['.##.', '####', '####', '.##.'];
}
