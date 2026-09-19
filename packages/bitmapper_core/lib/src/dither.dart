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
  // Frankie Sierra's two-row variant: between Sierra and Sierra Lite.
  'sierra_two_row': DiffusionKernel(16, [
    DiffusionTap(1, 0, 4), DiffusionTap(2, 0, 3), //
    DiffusionTap(-2, 1, 1), DiffusionTap(-1, 1, 2), DiffusionTap(0, 1, 3),
    DiffusionTap(1, 1, 2), DiffusionTap(2, 1, 1),
  ]),
  // A cheap three-tap approximation of Floyd-Steinberg.
  'false_floyd_steinberg': DiffusionKernel(8, [
    DiffusionTap(1, 0, 3),
    DiffusionTap(0, 1, 3),
    DiffusionTap(1, 1, 2),
  ]),
  // All the error to the next pixel on the row: streaky, very lo-fi.
  'simple': DiffusionKernel(1, [DiffusionTap(1, 0, 1)]),
};

/// Error-diffusion kernels scanned serpentine (alternate rows right-to-left,
/// taps mirrored), which breaks up the diagonal "worm" artifacts of raster
/// order: method name -> kernel name.
const Map<String, String> kSerpentineMethods = {'floyd_steinberg_serpentine': 'floyd_steinberg'};

const _orderedSizes = {'ordered': 4, 'ordered_2x2': 2, 'ordered_8x8': 8, 'ordered_16x16': 16};

/// `none` first, then every other method sorted by name.
List<String> listDitherMethods() => [
  'none',
  ...([
    ...kDiffusionKernels.keys,
    ...kSerpentineMethods.keys,
    ..._orderedSizes.keys,
    'clustered_dot',
    'interleaved_gradient_noise',
    'random',
  ]..sort()),
];

/// Error diffusion onto `palette` with the named kernel: raster order, or
/// serpentine (odd rows right-to-left with mirrored taps).
RgbImage errorDiffusion(
  RgbImage image,
  Uint8List palette,
  String method, {
  double strength = 1.0,
  bool serpentine = false,
  CancelCheck? isCancelled,
}) {
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

  final search = PaletteSearch(palette);
  for (var y = 0; y < h; y++) {
    if (isCancelled != null && isCancelled()) throw const FilterCancelled();
    final reverse = serpentine && y.isOdd;
    for (var step = 0; step < w; step++) {
      final x = reverse ? w - 1 - step : step;
      final i = (y * w + x) * 3;
      final oldR = img[i], oldG = img[i + 1], oldB = img[i + 2];
      final k = search.nearest(oldR, oldG, oldB) * 3;
      final newR = palette[k].toDouble();
      final newG = palette[k + 1].toDouble();
      final newB = palette[k + 2].toDouble();
      img[i] = newR;
      img[i + 1] = newG;
      img[i + 2] = newB;
      final errR = oldR - newR, errG = oldG - newG, errB = oldB - newB;
      for (var t = 0; t < taps.length; t++) {
        final nx = reverse ? x - taps[t].dx : x + taps[t].dx;
        final ny = y + taps[t].dy;
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
RgbImage ordered(RgbImage image, Uint8List palette, {int matrixSize = 4, double strength = 1.0}) =>
    orderedWithMatrix(image, palette, bayerMatrix(matrixSize), matrixSize, strength: strength);

/// 4x4 clustered-dot threshold map: dots grow from the centre of each tile,
/// like a printed halftone screen.
const kClusteredDot = [
  12, 5, 6, 13, //
  4, 0, 1, 7, //
  11, 3, 2, 8, //
  15, 10, 9, 14,
];

/// Halftone-style ordered dithering with [kClusteredDot].
RgbImage clusteredDot(RgbImage image, Uint8List palette, {double strength = 1.0}) =>
    orderedWithMatrix(image, palette, kClusteredDot, 4, strength: strength);

/// Ordered dithering with any `size x size` threshold `matrix` (values
/// 0..size²-1, row-major), tiled over the image.
RgbImage orderedWithMatrix(
  RgbImage image,
  Uint8List palette,
  List<int> matrix,
  int size, {
  double strength = 1.0,
}) {
  final cells = size * size;
  final threshold = Float64List(cells);
  for (var i = 0; i < cells; i++) {
    threshold[i] = matrix[i] / cells - 0.5;
  }
  return _perturbAndQuantize(
    image,
    palette,
    (x, y) => threshold[(y % size) * size + x % size],
    strength,
  );
}

/// Ordered-style dithering with Jorge Jimenez's interleaved gradient noise:
/// a deterministic formula whose pattern looks close to blue noise (no
/// visible grid, finer grain than Bayer).
RgbImage interleavedGradientNoise(RgbImage image, Uint8List palette, {double strength = 1.0}) =>
    _perturbAndQuantize(image, palette, (x, y) {
      final inner = 0.06711056 * x + 0.00583715 * y;
      final outer = 52.9829189 * (inner - inner.floorToDouble());
      return outer - outer.floorToDouble() - 0.5;
    }, strength);

/// Add `threshold(x, y) * step * strength` (shared by all channels, in the
/// Python reference's operation order), clamp as floats, then quantize.
RgbImage _perturbAndQuantize(
  RgbImage image,
  Uint8List palette,
  double Function(int x, int y) threshold,
  double strength,
) {
  final step = _noiseStep(palette);
  final w = image.width, h = image.height;
  final perturbed = Float64List(image.data.length);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final t = threshold(x, y);
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
RgbImage randomDither(RgbImage image, Uint8List palette, {double strength = 1.0, int seed = 0}) {
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
RgbImage applyDither(
  RgbImage image,
  Uint8List palette,
  String method, {
  double strength = 1.0,
  int seed = 0,
  CancelCheck? isCancelled,
}) {
  if (strength < 0) {
    throw ArgumentError.value(strength, 'strength', 'must be >= 0');
  }
  if (method == 'none') {
    return RgbImage(image.width, image.height, nearestColor(image.data, palette));
  }
  if (kDiffusionKernels.containsKey(method)) {
    return errorDiffusion(image, palette, method, strength: strength, isCancelled: isCancelled);
  }
  final serpentineKernel = kSerpentineMethods[method];
  if (serpentineKernel != null) {
    return errorDiffusion(
      image,
      palette,
      serpentineKernel,
      strength: strength,
      serpentine: true,
      isCancelled: isCancelled,
    );
  }
  final size = _orderedSizes[method];
  if (size != null) {
    return ordered(image, palette, matrixSize: size, strength: strength);
  }
  if (method == 'clustered_dot') return clusteredDot(image, palette, strength: strength);
  if (method == 'interleaved_gradient_noise') {
    return interleavedGradientNoise(image, palette, strength: strength);
  }
  if (method == 'random') {
    return randomDither(image, palette, strength: strength, seed: seed);
  }
  throw ArgumentError('unknown dither method: "$method"');
}
