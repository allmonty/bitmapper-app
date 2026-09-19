import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/foundation.dart';

import '../services/gif_io.dart';
import '../services/video_exporter.dart';
import 'preset.dart';

const kMinColumns = 16;
const kMaxColumns = 512;

/// Deepest auto-generated palette (4096 colors). The slider's next stop is
/// [kTrueColorStop].
const kMaxAutoBitDepth = 12;

/// Fixed and custom palettes have at most 256 colors, so more bits than
/// this would change nothing.
const kMaxPaletteBitDepth = 8;

/// The bit-depth slider stop, one past [kMaxAutoBitDepth], meaning true
/// color (auto mode only).
const kTrueColorStop = kMaxAutoBitDepth + 1;

/// Bit depth used for the "true color" checkbox (auto mode, >= 16 bits).
const kTrueColorBitDepth = 24;

/// The app's starting look: auto palette, 16 colors, Floyd–Steinberg.
const kDefaultConfig = BitmapFilterConfig(
  gridCols: 120,
  gridRows: 120,
  bitDepth: 4,
  dither: 'floyd_steinberg',
);

const kDefaultCustomPalette = [0x000000, 0xFFFFFF];

/// Grid rows for `cols` columns over a `width x height` image, keeping the
/// cells square.
int rowsFor(int cols, int width, int height) {
  if (width <= 0 || height <= 0) return cols;
  final rows = (cols * height / width).round();
  return rows < 1 ? 1 : rows;
}

/// The filter settings being edited. Only [config] is state; the setters
/// keep it valid (e.g. a fixed palette name when switching to fixed mode).
class EditorModel extends ChangeNotifier {
  EditorModel({BitmapFilterConfig initial = kDefaultConfig}) : _config = initial;

  BitmapFilterConfig _config;
  BitmapFilterConfig get config => _config;

  /// Output size of animated GIF exports (not part of presets).
  GifSize _gifSize = const GifSizePerCell(4);
  GifSize get gifSize => _gifSize;

  void setGifSize(GifSize size) {
    if (size == _gifSize) return;
    _gifSize = size;
    notifyListeners();
  }

  /// Video export settings (not part of presets).
  VideoFormat _videoFormat = VideoFormat.mp4;
  Mp4Resolution _mp4Resolution = Mp4Resolution.original;
  int _gifFrameRate = 15;
  VideoFormat get videoFormat => _videoFormat;
  Mp4Resolution get mp4Resolution => _mp4Resolution;
  int get gifFrameRate => _gifFrameRate;

  void setVideoFormat(VideoFormat format) {
    if (format == _videoFormat) return;
    _videoFormat = format;
    notifyListeners();
  }

  void setMp4Resolution(Mp4Resolution resolution) {
    if (resolution == _mp4Resolution) return;
    _mp4Resolution = resolution;
    notifyListeners();
  }

  void setGifFrameRate(int fps) {
    if (fps == _gifFrameRate) return;
    _gifFrameRate = fps;
    notifyListeners();
  }

  int _lastPaletteDepth = kDefaultConfig.bitDepth;

  int get columns => _config.gridCols;

  /// Highest bit depth for the current palette mode.
  int get maxBitDepth =>
      _config.paletteMode == PaletteMode.auto ? kMaxAutoBitDepth : kMaxPaletteBitDepth;
  bool get trueColor => _config.bitDepth >= kTrueColorThreshold;

  /// The config to render for a `width x height` source: rows follow the
  /// image's aspect ratio, and columns never exceed the image width.
  BitmapFilterConfig configFor(int width, int height) {
    final cols = _config.gridCols.clamp(1, width < 1 ? 1 : width);
    return _config.copyWith(gridCols: cols, gridRows: rowsFor(cols, width, height));
  }

  void _set(BitmapFilterConfig next) {
    if (next == _config) return;
    next.validate();
    _config = next;
    notifyListeners();
  }

  void setPaletteMode(PaletteMode mode) {
    var next = _config.copyWith(paletteMode: mode);
    if (mode == PaletteMode.fixed && next.fixedPalette == null) {
      next = next.copyWith(fixedPalette: 'pico8');
    }
    if (mode == PaletteMode.custom && (next.customPalette?.isEmpty ?? true)) {
      next = next.copyWith(customPalette: kDefaultCustomPalette);
    }
    // True color and depths past 8 bits only exist in auto mode.
    if (mode != PaletteMode.auto && next.bitDepth > kMaxPaletteBitDepth) {
      next = next.copyWith(bitDepth: _lastPaletteDepth.clamp(1, kMaxPaletteBitDepth));
    }
    _set(next);
  }

  void setFixedPalette(String name) => _set(_config.copyWith(fixedPalette: name));
  void setPaletteAlgorithm(String algorithm) => _set(_config.copyWith(paletteAlgorithm: algorithm));

  /// Set the palette bit depth, clamped to [maxBitDepth]. In auto mode,
  /// [kTrueColorStop] or more switches to true color.
  void setBitDepth(int bits) {
    if (_config.paletteMode == PaletteMode.auto && bits >= kTrueColorStop) {
      setTrueColor(true);
      return;
    }
    bits = bits.clamp(1, maxBitDepth);
    _lastPaletteDepth = bits;
    _set(_config.copyWith(bitDepth: bits));
  }

  void setTrueColor(bool on) {
    if (on == trueColor) return;
    if (on) _lastPaletteDepth = _config.bitDepth;
    _set(
      _config.copyWith(
        bitDepth: on ? kTrueColorBitDepth : _lastPaletteDepth,
        paletteMode: on ? PaletteMode.auto : null,
      ),
    );
  }

  void setCustomPalette(List<int> colors) {
    if (colors.isEmpty) return;
    _set(_config.copyWith(customPalette: List.unmodifiable(colors)));
  }

  void setDither(String method) => _set(_config.copyWith(dither: method));
  void setDitherStrength(double v) => _set(_config.copyWith(ditherStrength: v));

  void setColumns(int cols) =>
      _set(_config.copyWith(gridCols: cols.clamp(kMinColumns, kMaxColumns)));

  void setBlockSampling(BlockSampling s) => _set(_config.copyWith(blockSampling: s));
  void setGridGap(int px) => _set(_config.copyWith(gridGapPx: px));
  void setGridGapColor(int rgb) => _set(_config.copyWith(gridGapColor: rgb & 0xFFFFFF));
  void setContrast(double v) => _set(_config.copyWith(contrast: v));
  void setSaturation(double v) => _set(_config.copyWith(saturation: v));
  void setGamma(double v) => _set(_config.copyWith(gamma: v));
  void setScanlines(double v) => _set(_config.copyWith(scanlines: v));
  void setOutline(double v) => _set(_config.copyWith(outline: v));
  void setOutlineMethod(String method) => _set(_config.copyWith(outlineMethod: method));
  void setOutlineInk(String ink) => _set(_config.copyWith(outlineInk: ink));
  void setShadeBands(int bands) => _set(_config.copyWith(shadeBands: bands));
  void setDespeckle(bool on) => _set(_config.copyWith(despeckle: on));

  void setPaletteStrategy(PaletteStrategy strategy) =>
      _set(_config.copyWith(paletteStrategy: strategy));
  void setPaletteSamples(int n) =>
      _set(_config.copyWith(paletteSamples: n.clamp(kMinPaletteSamples, kMaxPaletteSamples)));
  void setAnimateNoise(bool on) => _set(_config.copyWith(animateNoise: on));

  /// Settings that stay stable from frame to frame: one palette sampled
  /// across the animation, and ordered dithering (error diffusion shimmers).
  /// Offered to the user, never applied automatically.
  void applyAnimationFriendly() =>
      _set(_config.copyWith(paletteStrategy: PaletteStrategy.sampled, dither: 'ordered'));

  /// Whether [applyAnimationFriendly] would change anything.
  bool get isAnimationFriendly =>
      _config.paletteStrategy == PaletteStrategy.sampled && !isErrorDiffusion;

  /// Error-diffusion dithers change pattern whenever a pixel changes, so
  /// they may shimmer between animation frames.
  bool get isErrorDiffusion => kDiffusionKernels.containsKey(_config.dither);

  void resetAdjustments() => _set(_config.copyWith(contrast: 1, saturation: 1, gamma: 1));

  /// Apply a preset. Built-ins define the look plus, for pixel-art presets,
  /// a suggested column count; otherwise the current column count is kept.
  /// User presets restore everything, columns included.
  void applyPreset(AppPreset preset) {
    var next = preset.config;
    if (preset.builtIn) {
      final cols = (preset.columns ?? _config.gridCols).clamp(kMinColumns, kMaxColumns);
      next = next.copyWith(gridCols: cols);
    }
    if (next.bitDepth < kTrueColorThreshold) {
      _lastPaletteDepth = next.bitDepth.clamp(1, kMaxAutoBitDepth);
    }
    _set(next);
  }

  void reset() => _set(kDefaultConfig);
}
