import 'dart:math' as math;
import 'dart:typed_data';

import 'color.dart';
import 'image.dart';

/// `(v - 127.5) * amount + 127.5`: >1 increases contrast, <1 flattens, 0 is
/// flat mid-gray.
RgbImage adjustContrast(RgbImage image, double amount) {
  if (amount < 0) {
    throw ArgumentError.value(amount, 'amount', 'contrast must be >= 0');
  }
  final src = image.data;
  final out = Uint8List(src.length);
  for (var i = 0; i < src.length; i++) {
    out[i] = clampToByte((src[i] - 127.5) * amount + 127.5);
  }
  return RgbImage(image.width, image.height, out);
}

/// Blend each pixel with its luma: 1 is a no-op, 0 is grayscale, >1 boosts.
RgbImage adjustSaturation(RgbImage image, double amount) {
  if (amount < 0) {
    throw ArgumentError.value(amount, 'amount', 'saturation must be >= 0');
  }
  final src = image.data;
  final out = Uint8List(src.length);
  for (var i = 0; i < src.length; i += 3) {
    final r = src[i].toDouble(), g = src[i + 1].toDouble(), b = src[i + 2].toDouble();
    final luma = luminance(r, g, b);
    out[i] = clampToByte(luma + (r - luma) * amount);
    out[i + 1] = clampToByte(luma + (g - luma) * amount);
    out[i + 2] = clampToByte(luma + (b - luma) * amount);
  }
  return RgbImage(image.width, image.height, out);
}

/// `pow(v / 255, 1 / gamma) * 255`: >1 brightens midtones, <1 darkens them.
RgbImage adjustGamma(RgbImage image, double gamma) {
  if (gamma <= 0) {
    throw ArgumentError.value(gamma, 'gamma', 'must be > 0');
  }
  // Only 256 possible inputs, so build a lookup table once.
  final lut = Uint8List(256);
  final inv = 1.0 / gamma;
  for (var v = 0; v < 256; v++) {
    lut[v] = clampToByte(math.pow(v / 255.0, inv) * 255.0);
  }
  final src = image.data;
  final out = Uint8List(src.length);
  for (var i = 0; i < src.length; i++) {
    out[i] = lut[src[i]];
  }
  return RgbImage(image.width, image.height, out);
}

/// Contrast, then saturation, then gamma. Each step is skipped at 1.0 and
/// truncates to bytes before the next one runs.
RgbImage applyAdjustments(
  RgbImage image, {
  double contrast = 1.0,
  double saturation = 1.0,
  double gamma = 1.0,
}) {
  var out = image;
  if (contrast != 1.0) out = adjustContrast(out, contrast);
  if (saturation != 1.0) out = adjustSaturation(out, saturation);
  if (gamma != 1.0) out = adjustGamma(out, gamma);
  return out;
}
