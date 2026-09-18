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
  String get menuCamera => 'Take photo...';

  @override
  String get menuSave => 'Save as...';

  @override
  String get menuClose => 'Close image';

  @override
  String get menuPresets => 'Presets';

  @override
  String get menuSavePreset => 'Save current...';

  @override
  String get menuHelp => 'Help';

  @override
  String get menuAbout => 'About Bitmapper...';

  @override
  String get emptyTitle => 'Open an image';

  @override
  String get emptyBody => 'Pick a photo to turn into retro pixel art.';

  @override
  String get emptyGallery => 'Gallery...';

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
  String get errorLoad => 'Couldn\'t open that image.';

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
}
