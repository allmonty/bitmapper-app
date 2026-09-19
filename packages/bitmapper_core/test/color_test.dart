import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:test/test.dart';

void main() {
  test('packRgb and the channel getters round-trip', () {
    final packed = packRgb(0x12, 0x34, 0x56);
    expect(packed, 0x123456);
    expect([redOf(packed), greenOf(packed), blueOf(packed)], [0x12, 0x34, 0x56]);
    expect(unpackRgb(packed), [0x12, 0x34, 0x56]);
  });

  test('packedAt reads the color at a byte offset', () {
    final bytes = Uint8List.fromList([1, 2, 3, 250, 251, 252]);
    expect(packedAt(bytes, 3), 0xFAFBFC);
  });

  test('paletteFromPacked flattens packed colors to RGB bytes', () {
    expect(paletteFromPacked([0xFF0000, 0x00FF80]), [255, 0, 0, 0, 255, 128]);
  });

  test('packedColors keeps pixel order, colorSet only distinct colors', () {
    final rgb = [9, 9, 9, 0, 0, 0, 9, 9, 9];
    expect(packedColors(rgb), [0x090909, 0, 0x090909]);
    expect(colorSet(rgb), {0x090909, 0});
  });

  test('stride 4 skips the alpha byte of RGBA buffers', () {
    final rgba = [1, 2, 3, 255, 4, 5, 6, 0];
    expect(packedColors(rgba, stride: 4), [0x010203, 0x040506]);
    expect(colorSet(rgba, stride: 4), {0x010203, 0x040506});
  });

  test('luminance uses the Rec. 601 weights', () {
    expect(luminance(255, 255, 255), closeTo(255, 1e-9));
    expect(luminance(100, 0, 0), closeTo(29.9, 1e-9));
    expect(luminance(0, 100, 0), closeTo(58.7, 1e-9));
    expect(luminance(0, 0, 100), closeTo(11.4, 1e-9));
  });
}
