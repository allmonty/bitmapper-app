import 'dart:typed_data';

/// An 8-bit RGB image stored row-major as `(y * width + x) * 3 + channel`.
class RgbImage {
  RgbImage(this.width, this.height, this.data)
    : assert(width >= 0 && height >= 0),
      assert(
        data.length == width * height * 3,
        'expected ${width * height * 3} bytes, got ${data.length}',
      );

  /// A black image of the given size.
  RgbImage.blank(this.width, this.height) : data = Uint8List(width * height * 3);

  /// Build an RGB image from RGBA bytes, dropping alpha (no compositing).
  factory RgbImage.fromRgba(int width, int height, Uint8List rgba) {
    if (rgba.length != width * height * 4) {
      throw ArgumentError('expected ${width * height * 4} RGBA bytes, got ${rgba.length}');
    }
    final out = Uint8List(width * height * 3);
    for (var i = 0, j = 0; j < out.length; i += 4, j += 3) {
      out[j] = rgba[i];
      out[j + 1] = rgba[i + 1];
      out[j + 2] = rgba[i + 2];
    }
    return RgbImage(width, height, out);
  }

  final int width;
  final int height;
  final Uint8List data;

  int get pixelCount => width * height;

  /// RGBA bytes with opaque alpha, e.g. for `ui.decodeImageFromPixels`.
  Uint8List toRgba() {
    final out = Uint8List(width * height * 4);
    for (var i = 0, j = 0; i < data.length; i += 3, j += 4) {
      out[j] = data[i];
      out[j + 1] = data[i + 1];
      out[j + 2] = data[i + 2];
      out[j + 3] = 255;
    }
    return out;
  }

  RgbImage copy() => RgbImage(width, height, Uint8List.fromList(data));

  /// The pixel at (x, y) as `[r, g, b]`.
  List<int> pixel(int x, int y) {
    final i = (y * width + x) * 3;
    return [data[i], data[i + 1], data[i + 2]];
  }
}

/// Clamp to [0, 255] and truncate toward zero, matching NumPy's
/// `np.clip(x, 0, 255).astype(np.uint8)`. Never round here (migration doc
/// §6.3).
int clampToByte(double v) {
  if (v <= 0) return 0;
  if (v >= 255) return 255;
  return v.toInt();
}
