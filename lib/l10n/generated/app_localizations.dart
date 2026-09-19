import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('pt')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Bitmapper'**
  String get appTitle;

  /// No description provided for @windowTitle.
  ///
  /// In en, this message translates to:
  /// **'Bitmapper - {name}'**
  String windowTitle(String name);

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'(untitled)'**
  String get untitled;

  /// No description provided for @menuFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// No description provided for @menuOpen.
  ///
  /// In en, this message translates to:
  /// **'Open...'**
  String get menuOpen;

  /// No description provided for @menuCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera...'**
  String get menuCamera;

  /// No description provided for @menuSave.
  ///
  /// In en, this message translates to:
  /// **'Save as...'**
  String get menuSave;

  /// No description provided for @menuClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get menuClose;

  /// No description provided for @menuPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get menuPresets;

  /// No description provided for @menuSavePreset.
  ///
  /// In en, this message translates to:
  /// **'Save current...'**
  String get menuSavePreset;

  /// No description provided for @menuHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// No description provided for @menuAbout.
  ///
  /// In en, this message translates to:
  /// **'About Bitmapper...'**
  String get menuAbout;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Open a photo or video'**
  String get emptyTitle;

  /// No description provided for @emptyBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a photo, GIF or video to turn into retro pixel art.'**
  String get emptyBody;

  /// No description provided for @emptyCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera...'**
  String get emptyCamera;

  /// No description provided for @holdToCompare.
  ///
  /// In en, this message translates to:
  /// **'Hold to compare'**
  String get holdToCompare;

  /// No description provided for @tabPalette.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get tabPalette;

  /// No description provided for @tabDither.
  ///
  /// In en, this message translates to:
  /// **'Dither'**
  String get tabDither;

  /// No description provided for @tabGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get tabGrid;

  /// No description provided for @tabAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get tabAdjust;

  /// No description provided for @tabEffects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get tabEffects;

  /// No description provided for @tabPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get tabPresets;

  /// No description provided for @paletteMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get paletteMode;

  /// No description provided for @paletteAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (from image)'**
  String get paletteAuto;

  /// No description provided for @paletteFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get paletteFixed;

  /// No description provided for @paletteCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get paletteCustom;

  /// No description provided for @paletteAlgorithm.
  ///
  /// In en, this message translates to:
  /// **'Algorithm'**
  String get paletteAlgorithm;

  /// No description provided for @algoMedianCut.
  ///
  /// In en, this message translates to:
  /// **'Median cut'**
  String get algoMedianCut;

  /// No description provided for @algoKmeans.
  ///
  /// In en, this message translates to:
  /// **'K-means'**
  String get algoKmeans;

  /// No description provided for @fixedPalette.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get fixedPalette;

  /// No description provided for @colorsGroup.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get colorsGroup;

  /// No description provided for @bitDepth.
  ///
  /// In en, this message translates to:
  /// **'Bit depth: {bits} ({colors} colors)'**
  String bitDepth(int bits, int colors);

  /// No description provided for @trueColor.
  ///
  /// In en, this message translates to:
  /// **'True color (no quantizing)'**
  String get trueColor;

  /// No description provided for @customColors.
  ///
  /// In en, this message translates to:
  /// **'Custom colors'**
  String get customColors;

  /// No description provided for @addColor.
  ///
  /// In en, this message translates to:
  /// **'Add...'**
  String get addColor;

  /// No description provided for @editColor.
  ///
  /// In en, this message translates to:
  /// **'Edit...'**
  String get editColor;

  /// No description provided for @removeColor.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeColor;

  /// No description provided for @ditherMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get ditherMethod;

  /// No description provided for @ditherStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength: {percent}%'**
  String ditherStrength(int percent);

  /// No description provided for @gridColumns.
  ///
  /// In en, this message translates to:
  /// **'Pixel columns: {cols}'**
  String gridColumns(int cols);

  /// No description provided for @gridSampling.
  ///
  /// In en, this message translates to:
  /// **'Block sampling'**
  String get gridSampling;

  /// No description provided for @samplingAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get samplingAverage;

  /// No description provided for @samplingNearest.
  ///
  /// In en, this message translates to:
  /// **'Nearest (center)'**
  String get samplingNearest;

  /// No description provided for @gridGap.
  ///
  /// In en, this message translates to:
  /// **'Grid gap: {px} px'**
  String gridGap(int px);

  /// No description provided for @gridGapColor.
  ///
  /// In en, this message translates to:
  /// **'Gap color...'**
  String get gridGapColor;

  /// No description provided for @adjustContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast: {value}'**
  String adjustContrast(String value);

  /// No description provided for @adjustSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation: {value}'**
  String adjustSaturation(String value);

  /// No description provided for @adjustGamma.
  ///
  /// In en, this message translates to:
  /// **'Gamma: {value}'**
  String adjustGamma(String value);

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @effectScanlines.
  ///
  /// In en, this message translates to:
  /// **'Scanlines: {percent}%'**
  String effectScanlines(int percent);

  /// No description provided for @presetsApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get presetsApply;

  /// No description provided for @presetsSave.
  ///
  /// In en, this message translates to:
  /// **'Save current...'**
  String get presetsSave;

  /// No description provided for @presetsRename.
  ///
  /// In en, this message translates to:
  /// **'Rename...'**
  String get presetsRename;

  /// No description provided for @presetsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get presetsDelete;

  /// No description provided for @presetBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'{name} (built-in)'**
  String presetBuiltIn(String name);

  /// No description provided for @presetNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Save preset'**
  String get presetNameTitle;

  /// No description provided for @presetNamePrompt.
  ///
  /// In en, this message translates to:
  /// **'Preset name:'**
  String get presetNamePrompt;

  /// No description provided for @presetDefaultName.
  ///
  /// In en, this message translates to:
  /// **'My preset'**
  String get presetDefaultName;

  /// No description provided for @renameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename preset'**
  String get renameTitle;

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete preset'**
  String get deleteTitle;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteConfirm(String name);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @statusNoImage.
  ///
  /// In en, this message translates to:
  /// **'No image'**
  String get statusNoImage;

  /// No description provided for @statusCells.
  ///
  /// In en, this message translates to:
  /// **'{cols}×{rows} cells'**
  String statusCells(int cols, int rows);

  /// No description provided for @statusColors.
  ///
  /// In en, this message translates to:
  /// **'{count} colors'**
  String statusColors(int count);

  /// No description provided for @statusMs.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String statusMs(int ms);

  /// No description provided for @statusWorking.
  ///
  /// In en, this message translates to:
  /// **'Working...'**
  String get statusWorking;

  /// No description provided for @statusSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {name}'**
  String statusSaved(String name);

  /// No description provided for @statusSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get statusSaving;

  /// No description provided for @savingTitle.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get savingTitle;

  /// No description provided for @savingBody.
  ///
  /// In en, this message translates to:
  /// **'Rendering the full-size image...'**
  String get savingBody;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Bitmapper'**
  String get errorTitle;

  /// No description provided for @errorLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open that file.'**
  String get errorLoad;

  /// No description provided for @errorSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the image.'**
  String get errorSave;

  /// No description provided for @errorFilter.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t apply the filter.'**
  String get errorFilter;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Bitmapper'**
  String get aboutTitle;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'Bitmapper {version}\nA retro pixel-art photo filter.'**
  String aboutBody(String version);

  /// No description provided for @tabAnimation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get tabAnimation;

  /// No description provided for @frameLabel.
  ///
  /// In en, this message translates to:
  /// **'Frame {current} / {total}'**
  String frameLabel(int current, int total);

  /// No description provided for @paletteAcrossFrames.
  ///
  /// In en, this message translates to:
  /// **'Palette across frames'**
  String get paletteAcrossFrames;

  /// No description provided for @strategyFirst.
  ///
  /// In en, this message translates to:
  /// **'First frame'**
  String get strategyFirst;

  /// No description provided for @strategySampled.
  ///
  /// In en, this message translates to:
  /// **'Sampled frames'**
  String get strategySampled;

  /// No description provided for @strategyPerFrame.
  ///
  /// In en, this message translates to:
  /// **'Each frame (may flicker)'**
  String get strategyPerFrame;

  /// No description provided for @paletteSamples.
  ///
  /// In en, this message translates to:
  /// **'Samples: {count} frames'**
  String paletteSamples(int count);

  /// No description provided for @strategyOnlyAuto.
  ///
  /// In en, this message translates to:
  /// **'Only applies to auto palettes.'**
  String get strategyOnlyAuto;

  /// No description provided for @animateNoise.
  ///
  /// In en, this message translates to:
  /// **'Animate random noise'**
  String get animateNoise;

  /// No description provided for @gifSize.
  ///
  /// In en, this message translates to:
  /// **'GIF size'**
  String get gifSize;

  /// No description provided for @gifOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original size ({width}×{height})'**
  String gifOriginal(int width, int height);

  /// No description provided for @gifPerCell.
  ///
  /// In en, this message translates to:
  /// **'Pixels per cell'**
  String get gifPerCell;

  /// No description provided for @gifPerCellValue.
  ///
  /// In en, this message translates to:
  /// **'{pixels} px per cell ({width}×{height})'**
  String gifPerCellValue(int pixels, int width, int height);

  /// No description provided for @animationFriendly.
  ///
  /// In en, this message translates to:
  /// **'Use animation-friendly settings'**
  String get animationFriendly;

  /// No description provided for @animationFriendlyHint.
  ///
  /// In en, this message translates to:
  /// **'One palette sampled across frames and ordered dithering, which stay stable between frames.'**
  String get animationFriendlyHint;

  /// No description provided for @statusShimmer.
  ///
  /// In en, this message translates to:
  /// **'Dither may shimmer between frames'**
  String get statusShimmer;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Saving animation'**
  String get exportTitle;

  /// No description provided for @exportProgress.
  ///
  /// In en, this message translates to:
  /// **'Frame {done} of {total}'**
  String exportProgress(int done, int total);

  /// No description provided for @exportPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get exportPreparing;

  /// No description provided for @statusSavedLossy.
  ///
  /// In en, this message translates to:
  /// **'Saved {name} (some frames reduced to 256 colors)'**
  String statusSavedLossy(String name);

  /// No description provided for @gifColorLimit.
  ///
  /// In en, this message translates to:
  /// **'GIF supports up to 256 colors per frame; deeper palettes are reduced when saving.'**
  String get gifColorLimit;

  /// No description provided for @animationTruncated.
  ///
  /// In en, this message translates to:
  /// **'This GIF is long, so only the first {count} frames were loaded.'**
  String animationTruncated(int count);

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get exportFormat;

  /// No description provided for @formatMp4.
  ///
  /// In en, this message translates to:
  /// **'MP4 video (with sound)'**
  String get formatMp4;

  /// No description provided for @formatGif.
  ///
  /// In en, this message translates to:
  /// **'Animated GIF (no sound)'**
  String get formatGif;

  /// No description provided for @mp4Resolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get mp4Resolution;

  /// No description provided for @resOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original size'**
  String get resOriginal;

  /// No description provided for @res720.
  ///
  /// In en, this message translates to:
  /// **'720p'**
  String get res720;

  /// No description provided for @res480.
  ///
  /// In en, this message translates to:
  /// **'480p'**
  String get res480;

  /// No description provided for @gifFrameRate.
  ///
  /// In en, this message translates to:
  /// **'GIF frame rate: {fps} fps'**
  String gifFrameRate(int fps);

  /// No description provided for @exportVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Saving video'**
  String get exportVideoTitle;

  /// No description provided for @statusSampling.
  ///
  /// In en, this message translates to:
  /// **'Sampling frames...'**
  String get statusSampling;

  /// No description provided for @audioUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This video\'s sound uses a format that can\'t be copied into an MP4, so saved videos will be silent. The picture is not affected.'**
  String get audioUnsupported;

  /// No description provided for @audioUnsupportedShort.
  ///
  /// In en, this message translates to:
  /// **'This video\'s sound can\'t be kept; the MP4 will be silent.'**
  String get audioUnsupportedShort;

  /// No description provided for @statusSavedNoSound.
  ///
  /// In en, this message translates to:
  /// **'Saved {name} (without sound)'**
  String statusSavedNoSound(String name);

  /// No description provided for @emptyOpen.
  ///
  /// In en, this message translates to:
  /// **'Open...'**
  String get emptyOpen;

  /// No description provided for @cameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraTitle;

  /// No description provided for @cameraPrompt.
  ///
  /// In en, this message translates to:
  /// **'Take a photo or record a video?'**
  String get cameraPrompt;

  /// No description provided for @cameraPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get cameraPhoto;

  /// No description provided for @cameraVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get cameraVideo;

  /// No description provided for @effectOutline.
  ///
  /// In en, this message translates to:
  /// **'Outline: {percent}%'**
  String effectOutline(int percent);

  /// No description provided for @toonGroup.
  ///
  /// In en, this message translates to:
  /// **'Toon'**
  String get toonGroup;

  /// No description provided for @effectShadeBands.
  ///
  /// In en, this message translates to:
  /// **'Shade bands: {bands}'**
  String effectShadeBands(int bands);

  /// No description provided for @effectShadeBandsOff.
  ///
  /// In en, this message translates to:
  /// **'Shade bands: off'**
  String get effectShadeBandsOff;

  /// No description provided for @effectDespeckle.
  ///
  /// In en, this message translates to:
  /// **'Clean up stray pixels'**
  String get effectDespeckle;

  /// No description provided for @outlineMethod.
  ///
  /// In en, this message translates to:
  /// **'Outline edges'**
  String get outlineMethod;

  /// No description provided for @outlineInk.
  ///
  /// In en, this message translates to:
  /// **'Outline ink'**
  String get outlineInk;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
