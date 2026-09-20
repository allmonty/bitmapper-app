import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';

import '../repositories/preset_repository.dart';
import '../repositories/shared_prefs_preset_repository.dart';
import 'animation_exporter.dart';
import 'export_notifier.dart';
import 'filter_controller.dart';
import 'image_codec.dart';
import 'image_loader.dart';
import 'image_saver.dart';
import 'share_intent_source.dart';
import 'video_exporter.dart';
import 'video_io.dart';

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
    this.videoIO = const PluginVideoIO(),
    this.videoExporter = exportVideoInIsolate,
    this.previewDebounce = const Duration(milliseconds: 120),
    this.clock = DateTime.now,
    this.exportNotifier = const NoopExportNotifier(),
    this.shareIntentSource = const NoopShareIntentSource(),
  });

  factory AppServices.production() => AppServices(
    imageLoader: PickerImageLoader(),
    imageSaver: const FileDialogImageSaver(),
    presetRepository: SharedPrefsPresetRepository(),
    // A reused worker isolate for live preview, instead of the default
    // spawn-per-call runInIsolate: preview requests happen far more often
    // (debounced but continuous) than export's one-shot isolates, so the
    // spawn/teardown cost is worth avoiding here specifically.
    filterRunner: PreviewIsolate().run,
    exportNotifier: LocalExportNotifier(),
    shareIntentSource: ReceiveSharingIntentSource(),
  );

  final ImageLoader imageLoader;
  final ImageSaver imageSaver;
  final PresetRepository presetRepository;
  final FilterRunner filterRunner;
  final PngEncoder pngEncoder;
  final GifExporter gifExporter;

  /// Reads video for the preview (on the UI isolate).
  final VideoIO videoIO;
  final VideoExporter videoExporter;
  final Duration previewDebounce;
  final DateTime Function() clock;

  /// Shows export progress as an OS notification. Defaults to a no-op so
  /// tests never touch a platform channel that doesn't exist under
  /// `flutter_test`; `.production()` overrides it with a real one.
  final ExportNotifier exportNotifier;

  /// Media shared into the app from another app (Android only so far).
  /// Defaults to a no-op for the same reason as [exportNotifier].
  final ShareIntentSource shareIntentSource;
}
