import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:image/image.dart' as img;

/// Longest edge kept when loading an animated GIF. Every frame is held in
/// memory, so this is smaller than the still-image cap.
const kMaxAnimationDimension = 640;

/// Most frames loaded from one GIF.
const kMaxAnimationFrames = 1000;

/// Total pixels kept across all frames (~190 MB of RGB); frames past the
/// budget are dropped and the animation is marked truncated.
const kMaxAnimationPixels = 64 * 1000 * 1000;

/// Frame delay used when a GIF says 0 (browsers treat that as ~100 ms).
const kDefaultFrameDurationMs = 100;

/// An animation decoded to full RGB frames.
class DecodedAnimation {
  const DecodedAnimation({
    required this.frames,
    required this.durationsMs,
    required this.loopCount,
    this.truncated = false,
    this.downscaled = false,
  });

  final List<RgbImage> frames;
  final List<int> durationsMs;

  /// 0 loops forever.
  final int loopCount;

  /// More than [kMaxAnimationFrames] frames; the rest were dropped.
  final bool truncated;

  /// Frames were scaled down to [kMaxAnimationDimension].
  final bool downscaled;

  int get frameCount => frames.length;
  int get width => frames.first.width;
  int get height => frames.first.height;
}

/// True when `bytes` start with a GIF signature.
bool isGif(Uint8List bytes) =>
    bytes.length >= 6 &&
    bytes[0] == 0x47 && // G
    bytes[1] == 0x49 && // I
    bytes[2] == 0x46 && // F
    bytes[3] == 0x38; //   8

/// Decode every (composited) frame of a GIF. Pure Dart; run it in an
/// isolate for big files. Returns `null` if the bytes aren't a GIF.
DecodedAnimation? decodeGif(Uint8List bytes, {int maxDimension = kMaxAnimationDimension}) {
  final decoded = img.GifDecoder().decode(bytes);
  if (decoded == null) return null;
  final all = decoded.frames;
  var truncated = all.length > kMaxAnimationFrames;
  final frames = <RgbImage>[];
  final durations = <int>[];
  var downscaled = false;
  var pixels = 0;
  for (final frame in all.take(kMaxAnimationFrames)) {
    var rgb = _toRgb(frame);
    final longest = rgb.width > rgb.height ? rgb.width : rgb.height;
    if (longest > maxDimension) {
      final scale = maxDimension / longest;
      rgb = downsample(
        rgb,
        (rgb.width * scale).round().clamp(1, maxDimension),
        (rgb.height * scale).round().clamp(1, maxDimension),
      );
      downscaled = true;
    }
    pixels += rgb.width * rgb.height;
    if (pixels > kMaxAnimationPixels && frames.isNotEmpty) {
      truncated = true;
      break;
    }
    frames.add(rgb);
    durations.add(frame.frameDuration > 0 ? frame.frameDuration : kDefaultFrameDurationMs);
  }
  return DecodedAnimation(
    frames: frames,
    durationsMs: durations,
    loopCount: decoded.loopCount,
    truncated: truncated,
    downscaled: downscaled,
  );
}

RgbImage _toRgb(img.Image frame) {
  final rgb = frame.convert(format: img.Format.uint8, numChannels: 3);
  return RgbImage(rgb.width, rgb.height, Uint8List.fromList(rgb.toUint8List()));
}

/// How big an exported GIF is.
sealed class GifSize {
  const GifSize();

  /// Output dimensions for a `cols x rows` grid over a `width x height`
  /// source.
  (int, int) outputSize(int width, int height, int cols, int rows);
}

/// Same size as the source.
class GifSizeOriginal extends GifSize {
  const GifSizeOriginal();

  @override
  (int, int) outputSize(int width, int height, int cols, int rows) => (width, height);

  @override
  bool operator ==(Object other) => other is GifSizeOriginal;

  @override
  int get hashCode => 0;
}

/// Every grid cell is exactly `pixels x pixels`: crisp pixel art and small
/// files.
class GifSizePerCell extends GifSize {
  const GifSizePerCell(this.pixels) : assert(pixels >= 1);
  final int pixels;

  @override
  (int, int) outputSize(int width, int height, int cols, int rows) =>
      (cols * pixels, rows * pixels);

  @override
  bool operator ==(Object other) => other is GifSizePerCell && other.pixels == pixels;

  @override
  int get hashCode => pixels;
}

const kGifPixelsPerCell = [1, 2, 3, 4, 6, 8];

/// Streams filtered frames into an animated GIF.
///
/// A frame with at most 256 distinct colors (the palette plus any scanline
/// or grid-gap tints) is written as an indexed frame with exactly those
/// colors. Frames with more (bit depth > 8, true color, heavy scanlines)
/// don't fit GIF, so they fall back to the encoder's own quantizer without
/// dithering.
class GifWriter {
  GifWriter({int loopCount = 0})
    : _encoder = img.GifEncoder(repeat: loopCount, dither: img.DitherKernel.none);

  final img.GifEncoder _encoder;
  var _frames = 0;
  var _lossyFrames = 0;

  int get frameCount => _frames;

  /// Frames that had more than 256 colors and were quantized by the encoder.
  int get lossyFrames => _lossyFrames;

  /// Add one frame shown for `durationMs` (GIF stores 1/100 s).
  void addFrame(RgbImage frame, int durationMs) {
    final gifFrame = toGifFrame(frame);
    if (!gifFrame.hasPalette) _lossyFrames++;
    _encoder.addFrame(gifFrame, duration: (durationMs / 10).round().clamp(1, 65535));
    _frames++;
  }

  Uint8List finish() {
    if (_frames == 0) throw StateError('no frames added');
    return _encoder.finish()!;
  }
}

/// A GIF-ready frame: indexed with the frame's own colors when it has at
/// most 256 of them, otherwise plain RGB for the encoder to quantize.
img.Image toGifFrame(RgbImage frame) {
  final data = frame.data;
  final pixels = frame.width * frame.height;
  final indexOf = <int, int>{};
  final indices = Uint8List(pixels);
  for (var p = 0, i = 0; p < pixels; p++, i += 3) {
    final packed = packedAt(data, i);
    var index = indexOf[packed];
    if (index == null) {
      if (indexOf.length == 256) {
        return img.Image.fromBytes(
          width: frame.width,
          height: frame.height,
          bytes: data.buffer,
          bytesOffset: data.offsetInBytes,
          numChannels: 3,
        );
      }
      index = indexOf[packed] = indexOf.length;
    }
    indices[p] = index;
  }
  final palette = img.PaletteUint8(indexOf.length, 3);
  indexOf.forEach((packed, i) => palette.setRgb(i, redOf(packed), greenOf(packed), blueOf(packed)));
  final out = img.Image(width: frame.width, height: frame.height, numChannels: 1, palette: palette);
  out.data!.toUint8List().setAll(0, indices);
  return out;
}
