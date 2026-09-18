import 'dart:typed_data';

import 'package:bitmapper/main.dart';
import 'package:bitmapper/repositories/preset_repository.dart';
import 'package:bitmapper/services/app_services.dart';
import 'package:bitmapper/services/filter_controller.dart';
import 'package:bitmapper/services/image_codec.dart';
import 'package:bitmapper/services/image_loader.dart';
import 'package:bitmapper/services/image_saver.dart';
import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A `width x height` image with a diagonal color gradient.
RgbImage gradient(int width, int height) {
  final data = Uint8List(width * height * 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 3;
      data[i] = (x * 255) ~/ (width - 1);
      data[i + 1] = (y * 255) ~/ (height - 1);
      data[i + 2] = ((x + y) * 127) ~/ (width + height);
    }
  }
  return RgbImage(width, height, data);
}

class FakeImageLoader implements ImageLoader {
  FakeImageLoader({this.result, this.error});

  LoadedImage? result;
  Object? error;
  final List<ImageOrigin> calls = [];

  @override
  Future<LoadedImage?> load(ImageOrigin origin) async {
    calls.add(origin);
    if (error != null) throw error!;
    return result;
  }
}

class FakeImageSaver implements ImageSaver {
  final List<(Uint8List, String)> saved = [];
  Object? error;

  @override
  Future<String?> save(Uint8List png, String fileName) async {
    if (error != null) throw error!;
    saved.add((png, fileName));
    return '/fake/$fileName';
  }
}

/// Runs the real pipeline on the test's own isolate (Isolate.run doesn't
/// complete under the widget tester's fake async).
Future<FilterResult> syncRunner(FilterJob job) async => applyBitmapFilter(
  job.source,
  job.config,
  outputWidth: job.outputWidth,
  outputHeight: job.outputHeight,
);

class TestApp {
  TestApp({LoadedImage? image})
    : loader = FakeImageLoader(result: image),
      saver = FakeImageSaver(),
      repository = InMemoryPresetRepository();

  final FakeImageLoader loader;
  final FakeImageSaver saver;
  final InMemoryPresetRepository repository;

  AppServices get services => AppServices(
    imageLoader: loader,
    imageSaver: saver,
    presetRepository: repository,
    filterRunner: syncRunner,
    pngEncoder: (image) async => encodePng(image),
    clock: () => DateTime.fromMillisecondsSinceEpoch(1234),
  );

  Widget build({Locale locale = const Locale('en')}) =>
      BitmapperApp(services: services, locale: locale);
}

/// A phone-sized portrait viewport.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
