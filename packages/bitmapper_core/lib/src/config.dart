import 'dither.dart';
import 'grid.dart';
import 'outline.dart';
import 'palette_gen.dart';
import 'toon.dart';

const kMinBitDepth = 1;
const kMaxBitDepth = 24;

/// At or above this depth, auto mode skips palette generation and dithering
/// and passes the block-sampled colors straight through.
const kTrueColorThreshold = 16;

enum PaletteMode { auto, fixed, custom }

/// How an auto palette is chosen for an animation (a sequence of frames).
enum PaletteStrategy {
  /// Generate a palette for every frame (colors may flicker).
  perFrame,

  /// Generate one palette from the first frame and reuse it.
  firstFrame,

  /// Generate one palette from [BitmapFilterConfig.paletteSamples] frames
  /// spread across the animation.
  sampled,
}

const kMinPaletteSamples = 2;
const kMaxPaletteSamples = 32;

/// Every knob of the filter.
/// - The output size is an argument of `applyBitmapFilter` instead of a
///   config field (preview and export render the same config at different
///   sizes);
/// - colors (custom palette, gap color) are packed `0xRRGGBB` ints;
/// - `randomSeed` makes `random` dither deterministic;
/// - `paletteStrategy`, `paletteSamples` and `animateNoise` only matter for
///   animations (see `sequence.dart`).
class BitmapFilterConfig {
  const BitmapFilterConfig({
    this.gridCols = 200,
    this.gridRows = 200,
    this.bitDepth = 8,
    this.blockSampling = BlockSampling.average,
    this.paletteMode = PaletteMode.auto,
    this.paletteAlgorithm = 'median_cut',
    this.fixedPalette,
    this.customPalette,
    this.dither = 'none',
    this.ditherStrength = 1.0,
    this.scanlines = 0.0,
    this.gridGapPx = 0,
    this.gridGapColor = 0x000000,
    this.outline = 0.0,
    this.outlineMethod = 'brightness',
    this.outlineInk = 'darkest',
    this.outlineThickness = 1,
    this.outlineCloseGaps = false,
    this.shadeBands = 0,
    this.despeckle = false,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.gamma = 1.0,
    this.randomSeed = 0,
    this.paletteStrategy = PaletteStrategy.sampled,
    this.paletteSamples = 8,
    this.animateNoise = false,
  });

  final int gridCols;
  final int gridRows;
  final int bitDepth;
  final BlockSampling blockSampling;
  final PaletteMode paletteMode;
  final String paletteAlgorithm;
  final String? fixedPalette;
  final List<int>? customPalette;
  final String dither;
  final double ditherStrength;
  final double scanlines;
  final int gridGapPx;
  final int gridGapColor;

  /// Ink on edges found by [outlineMethod]: 0 = off, 1 = most edges.
  final double outline;

  /// How edges are found for [outline]. See [kOutlineMethods].
  final String outlineMethod;

  /// How the ink color is picked for [outline]. See [kOutlineInks].
  final String outlineInk;

  /// Line thickness for [outline], in grid cells. See
  /// [kMinOutlineThickness]/[kMaxOutlineThickness].
  final int outlineThickness;

  /// Bridge 1-cell gaps in the [outline] mask before inking.
  final bool outlineCloseGaps;

  /// Toon shading: 0 = off, else 2..8 flat brightness bands.
  final int shadeBands;

  /// Replace isolated cells with their most common neighbour color.
  final bool despeckle;
  final double contrast;
  final double saturation;
  final double gamma;
  final int randomSeed;
  final PaletteStrategy paletteStrategy;
  final int paletteSamples;

  /// Give `random` dither a different seed per frame (moving noise) instead
  /// of the same noise on every frame.
  final bool animateNoise;

  /// Color budget: `2 ^ bitDepth`.
  int get nColors => 1 << bitDepth;

  bool get isTrueColor => paletteMode == PaletteMode.auto && bitDepth >= kTrueColorThreshold;

  /// Throws [ArgumentError] describing the first invalid field.
  void validate() {
    if (gridCols < 1 || gridRows < 1) {
      throw ArgumentError('grid size must be >= 1, got ${gridCols}x$gridRows');
    }
    if (bitDepth < kMinBitDepth || bitDepth > kMaxBitDepth) {
      throw ArgumentError(
        'bitDepth must be between $kMinBitDepth and $kMaxBitDepth, got $bitDepth',
      );
    }
    if (!kPaletteAlgorithms.contains(paletteAlgorithm)) {
      throw ArgumentError('invalid paletteAlgorithm: "$paletteAlgorithm"');
    }
    if (!listDitherMethods().contains(dither)) {
      throw ArgumentError('invalid dither: "$dither"');
    }
    if (ditherStrength < 0) {
      throw ArgumentError('ditherStrength must be >= 0, got $ditherStrength');
    }
    if (scanlines < 0 || scanlines > 1) {
      throw ArgumentError('scanlines must be between 0 and 1, got $scanlines');
    }
    if (outline < 0 || outline > 1) {
      throw ArgumentError('outline must be between 0 and 1, got $outline');
    }
    if (!kOutlineMethods.contains(outlineMethod)) {
      throw ArgumentError('invalid outlineMethod: "$outlineMethod"');
    }
    if (!kOutlineInks.contains(outlineInk)) {
      throw ArgumentError('invalid outlineInk: "$outlineInk"');
    }
    if (outlineThickness < kMinOutlineThickness || outlineThickness > kMaxOutlineThickness) {
      throw ArgumentError(
        'outlineThickness must be between $kMinOutlineThickness and '
        '$kMaxOutlineThickness, got $outlineThickness',
      );
    }
    if (shadeBands != 0 && (shadeBands < kMinShadeBands || shadeBands > kMaxShadeBands)) {
      throw ArgumentError(
        'shadeBands must be 0 or $kMinShadeBands..$kMaxShadeBands, got $shadeBands',
      );
    }
    if (gridGapPx < 0) {
      throw ArgumentError('gridGapPx must be >= 0, got $gridGapPx');
    }
    if (contrast < 0) throw ArgumentError('contrast must be >= 0, got $contrast');
    if (saturation < 0) {
      throw ArgumentError('saturation must be >= 0, got $saturation');
    }
    if (gamma <= 0) throw ArgumentError('gamma must be > 0, got $gamma');
    if (paletteSamples < kMinPaletteSamples || paletteSamples > kMaxPaletteSamples) {
      throw ArgumentError(
        'paletteSamples must be between $kMinPaletteSamples and $kMaxPaletteSamples, got $paletteSamples',
      );
    }
    if (paletteMode == PaletteMode.fixed && (fixedPalette == null || fixedPalette!.isEmpty)) {
      throw ArgumentError('fixedPalette must be set when paletteMode is fixed');
    }
    if (paletteMode == PaletteMode.custom && (customPalette == null || customPalette!.isEmpty)) {
      throw ArgumentError('customPalette must be set when paletteMode is custom');
    }
  }

  BitmapFilterConfig copyWith({
    int? gridCols,
    int? gridRows,
    int? bitDepth,
    BlockSampling? blockSampling,
    PaletteMode? paletteMode,
    String? paletteAlgorithm,
    String? fixedPalette,
    List<int>? customPalette,
    String? dither,
    double? ditherStrength,
    double? scanlines,
    int? gridGapPx,
    int? gridGapColor,
    double? outline,
    String? outlineMethod,
    String? outlineInk,
    int? outlineThickness,
    bool? outlineCloseGaps,
    int? shadeBands,
    bool? despeckle,
    double? contrast,
    double? saturation,
    double? gamma,
    int? randomSeed,
    PaletteStrategy? paletteStrategy,
    int? paletteSamples,
    bool? animateNoise,
  }) {
    return BitmapFilterConfig(
      gridCols: gridCols ?? this.gridCols,
      gridRows: gridRows ?? this.gridRows,
      bitDepth: bitDepth ?? this.bitDepth,
      blockSampling: blockSampling ?? this.blockSampling,
      paletteMode: paletteMode ?? this.paletteMode,
      paletteAlgorithm: paletteAlgorithm ?? this.paletteAlgorithm,
      fixedPalette: fixedPalette ?? this.fixedPalette,
      customPalette: customPalette ?? this.customPalette,
      dither: dither ?? this.dither,
      ditherStrength: ditherStrength ?? this.ditherStrength,
      scanlines: scanlines ?? this.scanlines,
      gridGapPx: gridGapPx ?? this.gridGapPx,
      gridGapColor: gridGapColor ?? this.gridGapColor,
      outline: outline ?? this.outline,
      outlineMethod: outlineMethod ?? this.outlineMethod,
      outlineInk: outlineInk ?? this.outlineInk,
      outlineThickness: outlineThickness ?? this.outlineThickness,
      outlineCloseGaps: outlineCloseGaps ?? this.outlineCloseGaps,
      shadeBands: shadeBands ?? this.shadeBands,
      despeckle: despeckle ?? this.despeckle,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      gamma: gamma ?? this.gamma,
      randomSeed: randomSeed ?? this.randomSeed,
      paletteStrategy: paletteStrategy ?? this.paletteStrategy,
      paletteSamples: paletteSamples ?? this.paletteSamples,
      animateNoise: animateNoise ?? this.animateNoise,
    );
  }

  Map<String, Object?> toJson() => {
    'gridCols': gridCols,
    'gridRows': gridRows,
    'bitDepth': bitDepth,
    'blockSampling': blockSampling.name,
    'paletteMode': paletteMode.name,
    'paletteAlgorithm': paletteAlgorithm,
    'fixedPalette': fixedPalette,
    'customPalette': customPalette,
    'dither': dither,
    'ditherStrength': ditherStrength,
    'scanlines': scanlines,
    'gridGapPx': gridGapPx,
    'gridGapColor': gridGapColor,
    'outline': outline,
    'outlineMethod': outlineMethod,
    'outlineInk': outlineInk,
    'outlineThickness': outlineThickness,
    'outlineCloseGaps': outlineCloseGaps,
    'shadeBands': shadeBands,
    'despeckle': despeckle,
    'contrast': contrast,
    'saturation': saturation,
    'gamma': gamma,
    'randomSeed': randomSeed,
    'paletteStrategy': paletteStrategy.name,
    'paletteSamples': paletteSamples,
    'animateNoise': animateNoise,
  };

  /// Missing keys fall back to defaults, so older saved presets keep loading.
  factory BitmapFilterConfig.fromJson(Map<String, Object?> json) {
    const d = BitmapFilterConfig();
    T? get<T>(String key) => json[key] is T ? json[key] as T : null;
    double? getDouble(String key) => (json[key] as num?)?.toDouble();
    return BitmapFilterConfig(
      gridCols: get<int>('gridCols') ?? d.gridCols,
      gridRows: get<int>('gridRows') ?? d.gridRows,
      bitDepth: get<int>('bitDepth') ?? d.bitDepth,
      blockSampling:
          BlockSampling.values.where((e) => e.name == json['blockSampling']).firstOrNull ??
          d.blockSampling,
      paletteMode:
          PaletteMode.values.where((e) => e.name == json['paletteMode']).firstOrNull ??
          d.paletteMode,
      paletteAlgorithm: get<String>('paletteAlgorithm') ?? d.paletteAlgorithm,
      fixedPalette: get<String>('fixedPalette'),
      customPalette: (json['customPalette'] as List?)?.cast<int>().toList(),
      dither: get<String>('dither') ?? d.dither,
      ditherStrength: getDouble('ditherStrength') ?? d.ditherStrength,
      scanlines: getDouble('scanlines') ?? d.scanlines,
      gridGapPx: get<int>('gridGapPx') ?? d.gridGapPx,
      gridGapColor: get<int>('gridGapColor') ?? d.gridGapColor,
      outline: getDouble('outline') ?? d.outline,
      outlineMethod: get<String>('outlineMethod') ?? d.outlineMethod,
      outlineInk: get<String>('outlineInk') ?? d.outlineInk,
      outlineThickness: get<int>('outlineThickness') ?? d.outlineThickness,
      outlineCloseGaps: get<bool>('outlineCloseGaps') ?? d.outlineCloseGaps,
      shadeBands: get<int>('shadeBands') ?? d.shadeBands,
      despeckle: get<bool>('despeckle') ?? d.despeckle,
      contrast: getDouble('contrast') ?? d.contrast,
      saturation: getDouble('saturation') ?? d.saturation,
      gamma: getDouble('gamma') ?? d.gamma,
      randomSeed: get<int>('randomSeed') ?? d.randomSeed,
      paletteStrategy:
          PaletteStrategy.values.where((e) => e.name == json['paletteStrategy']).firstOrNull ??
          d.paletteStrategy,
      paletteSamples: get<int>('paletteSamples') ?? d.paletteSamples,
      animateNoise: get<bool>('animateNoise') ?? d.animateNoise,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BitmapFilterConfig) return false;
    return gridCols == other.gridCols &&
        gridRows == other.gridRows &&
        bitDepth == other.bitDepth &&
        blockSampling == other.blockSampling &&
        paletteMode == other.paletteMode &&
        paletteAlgorithm == other.paletteAlgorithm &&
        fixedPalette == other.fixedPalette &&
        _listEquals(customPalette, other.customPalette) &&
        dither == other.dither &&
        ditherStrength == other.ditherStrength &&
        scanlines == other.scanlines &&
        gridGapPx == other.gridGapPx &&
        gridGapColor == other.gridGapColor &&
        outline == other.outline &&
        outlineMethod == other.outlineMethod &&
        outlineInk == other.outlineInk &&
        outlineThickness == other.outlineThickness &&
        outlineCloseGaps == other.outlineCloseGaps &&
        shadeBands == other.shadeBands &&
        despeckle == other.despeckle &&
        contrast == other.contrast &&
        saturation == other.saturation &&
        gamma == other.gamma &&
        randomSeed == other.randomSeed &&
        paletteStrategy == other.paletteStrategy &&
        paletteSamples == other.paletteSamples &&
        animateNoise == other.animateNoise;
  }

  @override
  int get hashCode => Object.hashAll([
    gridCols,
    gridRows,
    bitDepth,
    blockSampling,
    paletteMode,
    paletteAlgorithm,
    fixedPalette,
    customPalette == null ? null : Object.hashAll(customPalette!),
    dither,
    ditherStrength,
    scanlines,
    gridGapPx,
    gridGapColor,
    outline,
    outlineMethod,
    outlineInk,
    outlineThickness,
    outlineCloseGaps,
    shadeBands,
    despeckle,
    contrast,
    saturation,
    gamma,
    randomSeed,
    paletteStrategy,
    paletteSamples,
    animateNoise,
  ]);

  @override
  String toString() => 'BitmapFilterConfig(${toJson()})';
}

bool _listEquals(List<int>? a, List<int>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
