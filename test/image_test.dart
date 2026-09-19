import 'dart:typed_data';

import 'package:bitmapper/models/media_model.dart';
import 'package:bitmapper/services/image_codec.dart';
import 'package:bitmapper/services/image_loader.dart';
import 'package:bitmapper/services/image_saver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'helpers.dart';

void main() {
  group('fitWithin', () {
    test('leaves small images alone', () {
      expect(fitWithin(800, 600, 1024), (800, 600));
    });
    test('scales the longest edge down, keeping aspect', () {
      expect(fitWithin(4000, 3000, 1000), (1000, 750));
      expect(fitWithin(3000, 4000, 1000), (750, 1000));
      expect(fitWithin(10000, 5, 1000), (1000, 1));
    });
  });

  test('makePreviewSource downsizes large images only', () {
    final small = gradient(100, 50);
    expect(identical(makePreviewSource(small), small), isTrue);
    final big = makePreviewSource(gradient(2048, 1024));
    expect(big.width, kPreviewDimension);
    expect(big.height, 512);
  });

  test('encodePng produces a PNG that decodes back to the same pixels', () {
    final source = gradient(17, 9);
    final png = encodePng(source);
    expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final decoded = img.decodePng(png)!;
    expect(decoded.width, 17);
    expect(decoded.height, 9);
    final p = decoded.getPixel(16, 8);
    expect([p.r, p.g, p.b], source.pixel(16, 8));
  });

  test('encodeBmp writes a top-down 24-bit bitmap with padded rows', () {
    final source = gradient(3, 2); // 9 bytes per row -> padded to 12
    final bmp = encodeBmp(source);
    final bd = ByteData.view(bmp.buffer);
    expect(String.fromCharCodes(bmp.sublist(0, 2)), 'BM');
    expect(bmp.length, 54 + 12 * 2);
    expect(bd.getInt32(18, Endian.little), 3);
    expect(bd.getInt32(22, Endian.little), -2);
    expect(bd.getUint16(28, Endian.little), 24);
    // First pixel, stored as BGR.
    expect(bmp.sublist(54, 57), source.pixel(0, 0).reversed.toList());
    // Second row starts after the padding.
    expect(bmp.sublist(54 + 12, 54 + 15), source.pixel(0, 1).reversed.toList());
    // And it decodes.
    final decoded = img.decodeBmp(bmp)!;
    final p = decoded.getPixel(2, 1);
    expect([p.r, p.g, p.b], source.pixel(2, 1));
  });

  testWidgets('decodeToRgb decodes with the platform codec and caps size', (tester) async {
    final png = encodePng(gradient(40, 20));
    final full = (await tester.runAsync(() => decodeToRgb(png)))!;
    expect(full.width, 40);
    expect(full.height, 20);
    expect(full.pixel(39, 19), gradient(40, 20).pixel(39, 19));

    final capped = (await tester.runAsync(() => decodeToRgb(png, maxDimension: 10)))!;
    expect(capped.width, 10);
    expect(capped.height, 5);
  });

  test('exportFileName is timestamped', () {
    expect(exportFileName(DateTime.fromMillisecondsSinceEpoch(42)), 'bitmapper_42.png');
  });

  group('MediaModel', () {
    test('load sets full and preview images', () async {
      final loader = FakeImageLoader(
        result: LoadedImage(name: 'cat.png', image: gradient(2000, 1000)),
      );
      final model = MediaModel(loader);
      expect(await model.load(MediaRequest.library), isTrue);
      expect(model.hasImage, isTrue);
      expect(model.name, 'cat.png');
      expect(model.full!.width, 2000);
      expect(model.preview!.width, kPreviewDimension);
      expect(model.loading, isFalse);
      expect(loader.calls, [MediaRequest.library]);
    });

    test('cancelling keeps the current image', () async {
      final loader = FakeImageLoader(
        result: LoadedImage(name: 'a', image: gradient(10, 10)),
      );
      final model = MediaModel(loader);
      await model.load(MediaRequest.cameraPhoto);
      loader.result = null;
      expect(await model.load(MediaRequest.cameraPhoto), isFalse);
      expect(model.name, 'a');
    });

    test('errors propagate and reset the loading flag', () async {
      final model = MediaModel(FakeImageLoader(error: Exception('bad file')));
      await expectLater(model.load(MediaRequest.library), throwsException);
      expect(model.loading, isFalse);
      expect(model.hasImage, isFalse);
    });

    test('clear removes the image', () {
      final model = MediaModel(FakeImageLoader())..setImage('x', gradient(4, 4));
      model.clear();
      expect(model.hasImage, isFalse);
      expect(model.preview, isNull);
    });
  });

  group('isVideoFile', () {
    test('by extension, case-insensitive', () {
      for (final name in ['a.mp4', 'b.MOV', 'c.m4v', 'd.3gp', 'e.webm', 'f.mkv']) {
        expect(isVideoFile(name), isTrue, reason: name);
      }
      for (final name in ['a.jpg', 'b.png', 'c.gif', 'd.heic', 'noext', 'mp4']) {
        expect(isVideoFile(name), isFalse, reason: name);
      }
    });
    test('by MIME type when the name says nothing', () {
      expect(isVideoFile('picker_123', 'video/quicktime'), isTrue);
      expect(isVideoFile('picker_123', 'image/jpeg'), isFalse);
    });
  });
}
