import 'dart:typed_data';

import 'package:bitmapper/services/gif_io.dart';
import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('isGif checks the signature', () {
    expect(isGif(makeGif()), isTrue);
    expect(isGif(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0])), isFalse);
    expect(isGif(Uint8List(2)), isFalse);
  });

  test('decodeGif returns every frame with durations and loop count', () {
    final anim = decodeGif(makeGif(n: 3, loopCount: 2))!;
    expect(anim.frameCount, 3);
    expect(anim.width, 40);
    expect(anim.height, 30);
    expect(anim.durationsMs, [50, 100, 150]);
    expect(anim.loopCount, 2);
    expect(anim.truncated, isFalse);
    expect(anim.downscaled, isFalse);
    expect(anim.frames[0].data, isNot(anim.frames[1].data));
  });

  test('decodeGif scales big animations down', () {
    final anim = decodeGif(makeGif(n: 2, width: 200, height: 100), maxDimension: 50)!;
    expect(anim.width, 50);
    expect(anim.height, 25);
    expect(anim.downscaled, isTrue);
  });

  test('decodeGif returns null for non-GIF bytes', () {
    expect(decodeGif(Uint8List.fromList(List.filled(20, 7))), isNull);
  });

  test('filtered frames round-trip exactly (indexed, palette colors only)', () {
    final anim = decodeGif(makeGif(n: 3))!;
    const config = BitmapFilterConfig(
      gridCols: 10,
      gridRows: 8,
      paletteMode: PaletteMode.fixed,
      fixedPalette: 'pico8',
      bitDepth: 4,
      dither: 'ordered',
      scanlines: 0.3,
      gridGapPx: 1,
      gridGapColor: 0x123456,
    );
    final writer = GifWriter(loopCount: 1);
    final outputs = <RgbImage>[];
    for (var i = 0; i < anim.frameCount; i++) {
      final r = applyBitmapFilter(anim.frames[i], config, outputWidth: 30, outputHeight: 24);
      outputs.add(r.output);
      writer.addFrame(r.output, anim.durationsMs[i]);
    }
    expect(writer.lossyFrames, 0);
    final back = decodeGif(writer.finish())!;
    expect(back.frameCount, 3);
    expect(back.durationsMs, [50, 100, 150]);
    expect(back.loopCount, 1);
    for (var i = 0; i < 3; i++) {
      expect(back.frames[i].data, outputs[i].data, reason: 'frame $i is bit-exact');
    }
    expect(colorSet(back.frames[0].data), contains(0x123456), reason: 'gap color kept');
  });

  test('frames with more than 256 colors fall back to quantizing', () {
    final frame = gradient(64, 64); // thousands of colors
    final writer = GifWriter()..addFrame(frame, 100);
    expect(writer.lossyFrames, 1);
    final back = decodeGif(writer.finish())!;
    expect(back.frameCount, 1);
    expect(colorSet(back.frames.single.data).length, lessThanOrEqualTo(256));
  });

  test('toGifFrame is indexed for small palettes', () {
    final frame = RgbImage(2, 1, Uint8List.fromList([255, 0, 0, 0, 0, 255]));
    final gif = toGifFrame(frame);
    expect(gif.hasPalette, isTrue);
    expect(gif.palette!.numColors, 2);
  });

  test('finish without frames throws', () {
    expect(GifWriter().finish, throwsStateError);
  });

  group('GifSize', () {
    test('original keeps the source size', () {
      expect(const GifSizeOriginal().outputSize(400, 300, 120, 90), (400, 300));
    });
    test('per cell multiplies the grid', () {
      expect(const GifSizePerCell(4).outputSize(400, 300, 120, 90), (480, 360));
      expect(const GifSizePerCell(1).outputSize(400, 300, 120, 90), (120, 90));
    });
    test('equality', () {
      expect(const GifSizePerCell(2), const GifSizePerCell(2));
      expect(const GifSizePerCell(2), isNot(const GifSizePerCell(3)));
      expect(const GifSizeOriginal(), const GifSizeOriginal());
    });
  });
}
