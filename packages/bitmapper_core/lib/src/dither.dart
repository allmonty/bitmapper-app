import 'dart:math' as math;
import 'dart:typed_data';

import 'image.dart';
import 'prng.dart';
import 'quantize.dart';

/// Thrown by long-running stages when their cancellation check fires.
class FilterCancelled implements Exception {
  const FilterCancelled();
  @override
  String toString() => 'FilterCancelled';
}

/// Returns true when the current run should be abandoned.
typedef CancelCheck = bool Function();

/// One error-diffusion tap: push `weight / divisor` of the error to the
/// pixel at `(x + dx, y + dy)`.
class DiffusionTap {
  const DiffusionTap(this.dx, this.dy, this.weight);
  final int dx;
  final int dy;
  final int weight;
}

class DiffusionKernel {
  const DiffusionKernel(this.divisor, this.taps);
  final int divisor;
  final List<DiffusionTap> taps;
}

/// Error-diffusion kernels, kept as data so adding one is a one-line change
/// (and it's automatically listed by [listDitherMethods]).
const Map<String, DiffusionKernel> kDiffusionKernels = {
  'floyd_steinberg': DiffusionKernel(16, [
    DiffusionTap(1, 0, 7),
    DiffusionTap(-1, 1, 3),
    DiffusionTap(0, 1, 5),
    DiffusionTap(1, 1, 1),
  ]),
  'atkinson': DiffusionKernel(8, [
    DiffusionTap(1, 0, 1),
    DiffusionTap(2, 0, 1),
    DiffusionTap(-1, 1, 1),
    DiffusionTap(0, 1, 1),
    DiffusionTap(1, 1, 1),
    DiffusionTap(0, 2, 1),
  ]),
  'jarvis_judice_ninke': DiffusionKernel(48, [
    DiffusionTap(1, 0, 7), DiffusionTap(2, 0, 5), //
    DiffusionTap(-2, 1, 3), DiffusionTap(-1, 1, 5), DiffusionTap(0, 1, 7),
    DiffusionTap(1, 1, 5), DiffusionTap(2, 1, 3), //
    DiffusionTap(-2, 2, 1), DiffusionTap(-1, 2, 3), DiffusionTap(0, 2, 5),
    DiffusionTap(1, 2, 3), DiffusionTap(2, 2, 1),
  ]),
  'stucki': DiffusionKernel(42, [
    DiffusionTap(1, 0, 8), DiffusionTap(2, 0, 4), //
    DiffusionTap(-2, 1, 2), DiffusionTap(-1, 1, 4), DiffusionTap(0, 1, 8),
    DiffusionTap(1, 1, 4), DiffusionTap(2, 1, 2), //
    DiffusionTap(-2, 2, 1), DiffusionTap(-1, 2, 2), DiffusionTap(0, 2, 4),
    DiffusionTap(1, 2, 2), DiffusionTap(2, 2, 1),
  ]),
  'sierra': DiffusionKernel(32, [
    DiffusionTap(1, 0, 5), DiffusionTap(2, 0, 3), //
    DiffusionTap(-2, 1, 2), DiffusionTap(-1, 1, 4), DiffusionTap(0, 1, 5),
    DiffusionTap(1, 1, 4), DiffusionTap(2, 1, 2), //
    DiffusionTap(-1, 2, 2), DiffusionTap(0, 2, 3), DiffusionTap(1, 2, 2),
  ]),
  'sierra_lite': DiffusionKernel(4, [
    DiffusionTap(1, 0, 2),
    DiffusionTap(-1, 1, 1),
    DiffusionTap(0, 1, 1),
  ]),
  'burkes': DiffusionKernel(32, [
    DiffusionTap(1, 0, 8), DiffusionTap(2, 0, 4), //
    DiffusionTap(-2, 1, 2), DiffusionTap(-1, 1, 4), DiffusionTap(0, 1, 8),
    DiffusionTap(1, 1, 4), DiffusionTap(2, 1, 2),
  ]),
};

const _orderedSizes = {'ordered': 4, 'ordered_2x2': 2, 'ordered_8x8': 8};

/// `none` first, then every other method sorted by name.
List<String> listDitherMethods() => [
      'none',
      ...([...kDiffusionKernels.keys, ..._orderedSizes.keys, 'random']..sort()),
    ];

/// Raster-scan error diffusion onto `palette` with `kernel`.
RgbImage errorDiffusion(RgbImage image, Uint8List palette, String method,
    {double strength = 1.0, CancelCheck? isCancelled}) {
  final kernel = kDiffusionKernels[method];
  if (kernel == null) {
    throw ArgumentError('unknown error-diffusion kernel: "$method"');
  }
  final w = image.width, h = image.height;
  final img = Float64List(image.data.length);
  for (var i = 0; i < img.length; i++) {
    img[i] = image.data[i].toDouble();
  }
  // Fold divisor and strength into each tap once, as `(w * s) / d` — the
  // same operation order as the Python reference (migration doc §6.6).
  final taps = kernel.taps;
  final scaled = Float64List(taps.length);
  for (var t = 0; t < taps.length; t++) {
    scaled[t] = taps[t].weight * strength / kernel.divisor;
  }

  for (var y = 0; y < h; y++) {
    if (isCancelled != null && isCancelled()) throw const FilterCancelled();
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 3;
      final oldR = img[i], oldG = img[i + 1], oldB = img[i + 2];
      final k = nearestIndex(oldR, oldG, oldB, palette) * 3;
      final newR = palette[k].toDouble();
      final newG = palette[k + 1].toDouble();
      final newB = palette[k + 2].toDouble();
      img[i] = newR;
      img[i + 1] = newG;
      img[i + 2] = newB;
      final errR = oldR - newR, errG = oldG - newG, errB = oldB - newB;
      for (var t = 0; t < taps.length; t++) {
        final nx = x + taps[t].dx, ny = y + taps[t].dy;
        if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
          final j = (ny * w + nx) * 3;
          final s = scaled[t];
          img[j] += errR * s;
          img[j + 1] += errG * s;
          img[j + 2] += errB * s;
        }
      }
    }
  }
  final out = Uint8List(img.length);
  for (var i = 0; i < img.length; i++) {
    out[i] = clampToByte(img[i]);
  }
  return RgbImage(w, h, out);
}

/// Recursively-built `size x size` Bayer index matrix (values 0..size²-1),
/// row-major. `size` must be a power of two.
List<int> bayerMatrix(int size) {
  if (size < 1 || (size & (size - 1)) != 0) {
    throw ArgumentError.value(size, 'size', 'must be a power of two');
  }
  if (size == 1) return [0];
  final half = size ~/ 2;
  final smaller = bayerMatrix(half);
  final out = List<int>.filled(size * size, 0);
  for (var y = 0; y < half; y++) {
    for (var x = 0; x < half; x++) {
      final m = 4 * smaller[y * half + x];
      out[y * size + x] = m;
      out[y * size + x + half] = m + 2;
      out[(y + half) * size + x] = m + 3;
      out[(y + half) * size + x + half] = m + 1;
    }
  }
  return out;
}

/// Quantization step used to scale ordered/random noise: roughly the
/// palette's color spacing per channel.
double _noiseStep(Uint8List palette) {
  final n = math.max(palette.length ~/ 3, 2);
  return 255.0 / math.pow(n, 1 / 3);
}

double _clamp255(double v) => v < 0 ? 0 : (v > 255 ? 255 : v);

/// Ordered (Bayer) dithering with a `matrixSize` threshold map.
RgbImage ordered(RgbImage image, Uint8List palette,
    {int matrixSize = 4, double strength = 1.0}) {
  final matrix = bayerMatrix(matrixSize);
  final cells = matrixSize * matrixSize;
  final threshold = Float64List(cells);
  for (var i = 0; i < cells; i++) {
    threshold[i] = matrix[i] / cells - 0.5;
  }
  final step = _noiseStep(palette);
  final w = image.width, h = image.height;
  final perturbed = Float64List(image.data.length);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final t = threshold[(y % matrixSize) * matrixSize + x % matrixSize];
      final delta = t * step * strength;
      final i = (y * w + x) * 3;
      perturbed[i] = _clamp255(image.data[i] + delta);
      perturbed[i + 1] = _clamp255(image.data[i + 1] + delta);
      perturbed[i + 2] = _clamp255(image.data[i + 2] + delta);
    }
  }
  return RgbImage(w, h, nearestColorFloat(perturbed, palette));
}

/// White-noise dithering: uniform noise in [-0.5, 0.5) scaled to the
/// palette spacing, shared across channels. Deterministic for a `seed`.
RgbImage randomDither(RgbImage image, Uint8List palette,
    {double strength = 1.0, int seed = 0}) {
  final rng = XorShift128Plus(seed);
  final step = _noiseStep(palette);
  final perturbed = Float64List(image.data.length);
  for (var i = 0; i < perturbed.length; i += 3) {
    final noise = (rng.nextDouble() - 0.5) * step * strength;
    perturbed[i] = _clamp255(image.data[i] + noise);
    perturbed[i + 1] = _clamp255(image.data[i + 1] + noise);
    perturbed[i + 2] = _clamp255(image.data[i + 2] + noise);
  }
  return RgbImage(image.width, image.height, nearestColorFloat(perturbed, palette));
}

/// Dither `image` onto `palette` with `method` (see [listDitherMethods]).
/// `strength` 0 behaves like `none`; 1 is full-strength.
RgbImage applyDither(RgbImage image, Uint8List palette, String method,
    {double strength = 1.0, int seed = 0, CancelCheck? isCancelled}) {
  if (strength < 0) {
    throw ArgumentError.value(strength, 'strength', 'must be >= 0');
  }
  if (method == 'none') {
    return RgbImage(image.width, image.height, nearestColor(image.data, palette));
  }
  if (kDiffusionKernels.containsKey(method)) {
    return errorDiffusion(image, palette, method,
        strength: strength, isCancelled: isCancelled);
  }
  final size = _orderedSizes[method];
  if (size != null) {
    return ordered(image, palette, matrixSize: size, strength: strength);
  }
  if (method == 'random') {
    return randomDither(image, palette, strength: strength, seed: seed);
  }
  throw ArgumentError('unknown dither method: "$method"');
}
