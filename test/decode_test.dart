import 'dart:typed_data';

import 'package:bitmapper/services/image_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'helpers.dart';

/// 400x300 stored pixels: left half red, right half blue.
img.Image halves() {
  final image = img.Image(width: 400, height: 300);
  for (var y = 0; y < 300; y++) {
    for (var x = 0; x < 400; x++) {
      image.setPixelRgb(x, y, x < 200 ? 255 : 0, 0, x < 200 ? 0 : 255);
    }
  }
  return image;
}

bool reddish(List<int> p) => p[0] > 180 && p[2] < 80;
bool bluish(List<int> p) => p[2] > 180 && p[0] < 80;

void main() {
  group('decodeWithDart', () {
    test('JPEG without rotation keeps its shape', () {
      final rgb = decodeWithDart(img.encodeJpg(halves(), quality: 95))!;
      expect((rgb.width, rgb.height), (400, 300));
      expect(reddish(rgb.pixel(50, 150)), isTrue);
      expect(bluish(rgb.pixel(350, 150)), isTrue);
    });

    test('applies EXIF rotation (portrait phone photos)', () {
      // Orientation 6: rotate 90° clockwise to display -> red on top.
      final rotated = halves()..exif.imageIfd.orientation = 6;
      final cw = decodeWithDart(img.encodeJpg(rotated, quality: 95))!;
      expect((cw.width, cw.height), (300, 400));
      expect(reddish(cw.pixel(150, 50)), isTrue);
      expect(bluish(cw.pixel(150, 350)), isTrue);

      // Orientation 8: rotate 90° counter-clockwise -> red at the bottom.
      final ccwSource = halves()..exif.imageIfd.orientation = 8;
      final ccw = decodeWithDart(img.encodeJpg(ccwSource, quality: 95))!;
      expect((ccw.width, ccw.height), (300, 400));
      expect(reddish(ccw.pixel(150, 350)), isTrue);
    });

    test('scales down to the cap, keeping the shape', () {
      final rgb = decodeWithDart(img.encodePng(halves()), maxDimension: 100)!;
      expect((rgb.width, rgb.height), (100, 75));
      expect(rgb.pixel(10, 10), [255, 0, 0]);
      expect(rgb.pixel(90, 60), [0, 0, 255]);
    });

    test('PNG decodes exactly: alpha dropped, 16-bit and palette images converted', () {
      final source = gradient(37, 23); // odd sizes on purpose
      final png = img.Image.fromBytes(
        width: 37,
        height: 23,
        bytes: source.data.buffer,
        numChannels: 3,
      );
      expect(decodeWithDart(img.encodePng(png))!.data, source.data);

      final rgba = img.Image(width: 2, height: 1, numChannels: 4)
        ..setPixelRgba(0, 0, 10, 20, 30, 0)
        ..setPixelRgba(1, 0, 200, 100, 50, 255);
      expect(decodeWithDart(img.encodePng(rgba))!.data, [10, 20, 30, 200, 100, 50]);

      final deep = img.Image(width: 1, height: 1, format: img.Format.uint16)
        ..setPixelRgb(0, 0, 65535, 32896, 0);
      expect(decodeWithDart(img.encodePng(deep))!.data, [255, 128, 0]);

      final palette =
          img.Image(width: 2, height: 1, numChannels: 1, palette: img.PaletteUint8(2, 3))
            ..palette!.setRgb(0, 1, 2, 3)
            ..palette!.setRgb(1, 250, 251, 252)
            ..setPixelIndex(1, 0, 1);
      expect(decodeWithDart(img.encodePng(palette))!.data, [1, 2, 3, 250, 251, 252]);
    });

    test('returns null for data it can\'t decode', () {
      expect(decodeWithDart(Uint8List.fromList(List.filled(64, 7))), isNull);
      // A truncated JPEG.
      final jpg = img.encodeJpg(halves());
      expect(decodeWithDart(Uint8List.sublistView(jpg, 0, 200)), isNull);
    });
  });

  testWidgets('decodeToRgb matches the platform decoder for PNG', (tester) async {
    final png = img.encodePng(
      img.Image.fromBytes(
        width: 50,
        height: 40,
        bytes: gradient(50, 40).data.buffer,
        numChannels: 3,
      ),
    );
    final (dart, platform) = (await tester.runAsync(
      () async => (await decodeToRgb(png), await decodeWithPlatform(png)),
    ))!;
    expect((dart.width, dart.height), (50, 40));
    expect(dart.data, platform.data);
  });

  testWidgets('the platform fallback scales down too', (tester) async {
    final png = img.encodePng(halves());
    final platform = (await tester.runAsync(() => decodeWithPlatform(png, maxDimension: 100)))!;
    expect((platform.width, platform.height), (100, 75));
  });
}
