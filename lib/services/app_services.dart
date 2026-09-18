import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';

import '../repositories/preset_repository.dart';
import '../repositories/shared_prefs_preset_repository.dart';
import 'animation_exporter.dart';
import 'filter_controller.dart';
import 'image_codec.dart';
import 'image_loader.dart';
import 'image_saver.dart';

typedef PngEncoder = Future<Uint8List> Function(RgbImage image);

/// The app's side-effecting dependencies, injected at the root so tests can
/// swap in fakes.
class AppServices {
  const AppServices({
    required this.imageLoader,
    required this.imageSaver,
    required this.presetRepository,
    this.filterRunner = runInIsolate,
    this.pngEncoder = encodePngInBackground,
    this.gifExporter = exportGifInIsolate,
    this.previewDebounce = const Duration(milliseconds: 120),
    this.clock = DateTime.now,
  });

  factory AppServices.production() => AppServices(
    imageLoader: PickerImageLoader(),
    imageSaver: const FileDialogImageSaver(),
    presetRepository: SharedPrefsPresetRepository(),
  );

  final ImageLoader imageLoader;
  final ImageSaver imageSaver;
  final PresetRepository presetRepository;
  final FilterRunner filterRunner;
  final PngEncoder pngEncoder;
  final GifExporter gifExporter;
  final Duration previewDebounce;
  final DateTime Function() clock;
}
