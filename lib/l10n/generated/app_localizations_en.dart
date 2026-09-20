// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bitmapper';

  @override
  String windowTitle(String name) {
    return 'Bitmapper - $name';
  }

  @override
  String get untitled => '(untitled)';

  @override
  String get menuFile => 'File';

  @override
  String get menuOpen => 'Open...';

  @override
  String get menuCamera => 'Camera...';

  @override
  String get menuSave => 'Save as...';

  @override
  String get menuClose => 'Close';

  @override
  String get menuPresets => 'Presets';

  @override
  String get menuSavePreset => 'Save current...';

  @override
  String get menuHelp => 'Help';

  @override
  String get menuAbout => 'About Bitmapper...';

  @override
  String get emptyTitle => 'Open a photo or video';

  @override
  String get emptyBody => 'Pick a photo, GIF or video to turn into retro pixel art.';

  @override
  String get emptyCamera => 'Camera...';

  @override
  String get holdToCompare => 'Hold to compare';

  @override
  String get tabPalette => 'Palette';

  @override
  String get tabDither => 'Dither';

  @override
  String get tabGrid => 'Grid';

  @override
  String get tabAdjust => 'Adjust';

  @override
  String get tabEffects => 'Effects';

  @override
  String get tabPresets => 'Presets';

  @override
  String get paletteMode => 'Mode';

  @override
  String get paletteAuto => 'Auto (from image)';

  @override
  String get paletteFixed => 'Fixed';

  @override
  String get paletteCustom => 'Custom';

  @override
  String get paletteAlgorithm => 'Algorithm';

  @override
  String get algoMedianCut => 'Median cut';

  @override
  String get algoKmeans => 'K-means';

  @override
  String get fixedPalette => 'Palette';

  @override
  String get colorsGroup => 'Colors';

  @override
  String bitDepth(int bits, int colors) {
    return 'Bit depth: $bits ($colors colors)';
  }

  @override
  String get trueColor => 'True color (no quantizing)';

  @override
  String get customColors => 'Custom colors';

  @override
  String get addColor => 'Add...';

  @override
  String get editColor => 'Edit...';

  @override
  String get removeColor => 'Remove';

  @override
  String get ditherMethod => 'Method';

  @override
  String ditherStrength(int percent) {
    return 'Strength: $percent%';
  }

  @override
  String gridColumns(int cols) {
    return 'Pixel columns: $cols';
  }

  @override
  String get gridSampling => 'Block sampling';

  @override
  String get samplingAverage => 'Average';

  @override
  String get samplingNearest => 'Nearest (center)';

  @override
  String gridGap(int px) {
    return 'Grid gap: $px px';
  }

  @override
  String get gridGapColor => 'Gap color...';

  @override
  String adjustContrast(String value) {
    return 'Contrast: $value';
  }

  @override
  String adjustSaturation(String value) {
    return 'Saturation: $value';
  }

  @override
  String adjustGamma(String value) {
    return 'Gamma: $value';
  }

  @override
  String get reset => 'Reset';

  @override
  String effectScanlines(int percent) {
    return 'Scanlines: $percent%';
  }

  @override
  String get presetsApply => 'Apply';

  @override
  String get presetsSave => 'Save current...';

  @override
  String get presetsRename => 'Rename...';

  @override
  String get presetsDelete => 'Delete';

  @override
  String presetBuiltIn(String name) {
    return '$name (built-in)';
  }

  @override
  String get presetNameTitle => 'Save preset';

  @override
  String get presetNamePrompt => 'Preset name:';

  @override
  String get presetDefaultName => 'My preset';

  @override
  String get renameTitle => 'Rename preset';

  @override
  String get deleteTitle => 'Delete preset';

  @override
  String deleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get statusReady => 'Ready';

  @override
  String get statusNoImage => 'No image';

  @override
  String statusCells(int cols, int rows) {
    return '$cols×$rows cells';
  }

  @override
  String statusColors(int count) {
    return '$count colors';
  }

  @override
  String statusMs(int ms) {
    return '$ms ms';
  }

  @override
  String get statusWorking => 'Working...';

  @override
  String statusSaved(String name) {
    return 'Saved $name';
  }

  @override
  String get statusSaving => 'Saving...';

  @override
  String get savingTitle => 'Saving';

  @override
  String get savingBody => 'Rendering the full-size image...';

  @override
  String get errorTitle => 'Bitmapper';

  @override
  String get errorLoad => 'Couldn\'t open that file.';

  @override
  String get errorSave => 'Couldn\'t save the image.';

  @override
  String get errorFilter => 'Couldn\'t apply the filter.';

  @override
  String get aboutTitle => 'About Bitmapper';

  @override
  String aboutBody(String version) {
    return 'Bitmapper $version\nA retro pixel-art photo filter.';
  }

  @override
  String get tabAnimation => 'Animation';

  @override
  String frameLabel(int current, int total) {
    return 'Frame $current / $total';
  }

  @override
  String get paletteAcrossFrames => 'Palette across frames';

  @override
  String get strategyFirst => 'First frame';

  @override
  String get strategySampled => 'Sampled frames';

  @override
  String get strategyPerFrame => 'Each frame (may flicker)';

  @override
  String paletteSamples(int count) {
    return 'Samples: $count frames';
  }

  @override
  String get strategyOnlyAuto => 'Only applies to auto palettes.';

  @override
  String get animateNoise => 'Animate random noise';

  @override
  String frameSkip(int count) {
    return 'Skip frames: $count';
  }

  @override
  String frameSkipWithFps(int count, String fps) {
    return 'Skip frames: $count (~$fps fps)';
  }

  @override
  String get frameSkipOff => 'Skip frames: off';

  @override
  String frameSkipOffWithFps(String fps) {
    return 'Skip frames: off ($fps fps)';
  }

  @override
  String get gifSize => 'GIF size';

  @override
  String gifOriginal(int width, int height) {
    return 'Original size ($width×$height)';
  }

  @override
  String get gifPerCell => 'Pixels per cell';

  @override
  String gifPerCellValue(int pixels, int width, int height) {
    return '$pixels px per cell ($width×$height)';
  }

  @override
  String get animationFriendly => 'Use animation-friendly settings';

  @override
  String get animationFriendlyHint =>
      'One palette sampled across frames and ordered dithering, which stay stable between frames.';

  @override
  String get statusShimmer => 'Dither may shimmer between frames';

  @override
  String get exportTitle => 'Saving animation';

  @override
  String exportProgress(int done, int total) {
    return 'Frame $done of $total';
  }

  @override
  String get exportPreparing => 'Preparing...';

  @override
  String statusSavedLossy(String name) {
    return 'Saved $name (some frames reduced to 256 colors)';
  }

  @override
  String get gifColorLimit =>
      'GIF supports up to 256 colors per frame; deeper palettes are reduced when saving.';

  @override
  String animationTruncated(int count) {
    return 'This GIF is long, so only the first $count frames were loaded.';
  }

  @override
  String get exportFormat => 'Save as';

  @override
  String get formatMp4 => 'MP4 video (with sound)';

  @override
  String get formatGif => 'Animated GIF (no sound)';

  @override
  String get mp4Resolution => 'Resolution';

  @override
  String get resOriginal => 'Original size';

  @override
  String get res720 => '720p';

  @override
  String get res480 => '480p';

  @override
  String gifFrameRate(int fps) {
    return 'GIF frame rate: $fps fps';
  }

  @override
  String get exportVideoTitle => 'Saving video';

  @override
  String get statusSampling => 'Sampling frames...';

  @override
  String get audioUnsupported =>
      'This video\'s sound uses a format that can\'t be copied into an MP4, so saved videos will be silent. The picture is not affected.';

  @override
  String get audioUnsupportedShort => 'This video\'s sound can\'t be kept; the MP4 will be silent.';

  @override
  String statusSavedNoSound(String name) {
    return 'Saved $name (without sound)';
  }

  @override
  String get emptyOpen => 'Open...';

  @override
  String get cameraTitle => 'Camera';

  @override
  String get cameraPrompt => 'Take a photo or record a video?';

  @override
  String get cameraPhoto => 'Photo';

  @override
  String get cameraVideo => 'Video';

  @override
  String effectOutline(int percent) {
    return 'Outline: $percent%';
  }

  @override
  String get toonGroup => 'Toon';

  @override
  String effectShadeBands(int bands) {
    return 'Shade bands: $bands';
  }

  @override
  String get effectShadeBandsOff => 'Shade bands: off';

  @override
  String get effectDespeckle => 'Clean up stray pixels';

  @override
  String get outlineMethod => 'Outline edges';

  @override
  String get outlineInk => 'Outline ink';

  @override
  String effectOutlineThickness(int thickness) {
    return 'Line thickness: $thickness';
  }

  @override
  String get effectOutlineCloseGaps => 'Close small gaps';
}
