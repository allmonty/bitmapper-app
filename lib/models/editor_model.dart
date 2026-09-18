import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/foundation.dart';

import 'preset.dart';

const kMinColumns = 16;
const kMaxColumns = 320;

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

  int _lastPaletteDepth = kDefaultConfig.bitDepth;

  int get columns => _config.gridCols;
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
    // True color only exists in auto mode; fixed/custom cap at 8 bits here.
    if (mode != PaletteMode.auto && next.bitDepth > 8) {
      next = next.copyWith(bitDepth: _lastPaletteDepth);
    }
    _set(next);
  }

  void setFixedPalette(String name) => _set(_config.copyWith(fixedPalette: name));
  void setPaletteAlgorithm(String algorithm) => _set(_config.copyWith(paletteAlgorithm: algorithm));

  void setBitDepth(int bits) {
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

  void resetAdjustments() => _set(_config.copyWith(contrast: 1, saturation: 1, gamma: 1));

  /// Apply a preset. Built-ins only define the look, so the current column
  /// count is kept; user presets restore it too.
  void applyPreset(AppPreset preset) {
    var next = preset.config;
    if (preset.builtIn) next = next.copyWith(gridCols: _config.gridCols);
    // Built-in fixed/custom presets can use bit depth 8; keep true color off.
    if (next.bitDepth < kTrueColorThreshold) _lastPaletteDepth = next.bitDepth.clamp(1, 8);
    _set(next);
  }

  void reset() => _set(kDefaultConfig);
}
