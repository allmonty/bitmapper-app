import 'package:bitmapper/models/media_model.dart';
import 'package:bitmapper/screens/home_screen.dart';
import 'package:bitmapper/services/filter_controller.dart';
import 'package:bitmapper/services/image_loader.dart';
import 'package:bitmapper/widgets/rgb_image_view.dart';
import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  group('previewOutputSize', () {
    test('without a viewport, the source size', () {
      expect(previewOutputSize(1024, 768, null), (1024, 768));
    });

    test('fits the viewport, keeping the aspect ratio', () {
      expect(previewOutputSize(1024, 768, const Size(1400, 2000)), (1400, 1050));
      expect(previewOutputSize(768, 1024, const Size(1400, 900)), (675, 900));
    });

    test('scales small sources up to the viewport', () {
      expect(previewOutputSize(40, 30, const Size(400, 400)), (400, 300));
    });

    test('caps the long edge', () {
      final (w, h) = previewOutputSize(1000, 500, const Size(10000, 10000));
      expect(w, kMaxPreviewOutput);
      expect(h, kMaxPreviewOutput ~/ 2);
    });
  });

  test('FilterController renders to the viewport and re-renders when it changes', () {
    fakeAsync((async) {
      final jobs = <FilterJob>[];
      final controller = FilterController(
        runner: (job) async {
          jobs.add(job);
          return syncRunner(job);
        },
        debounce: const Duration(milliseconds: 10),
      );
      final source = gradient(100, 50);
      const config = BitmapFilterConfig(gridCols: 10, gridRows: 5, bitDepth: 16);

      controller.request(source, config);
      async.elapse(const Duration(milliseconds: 20));
      expect((jobs.last.outputWidth, jobs.last.outputHeight), (100, 50));

      controller.setViewport(const Size(900, 900));
      async.elapse(const Duration(milliseconds: 20));
      expect((jobs.last.outputWidth, jobs.last.outputHeight), (900, 450));
      expect(controller.result!.output.width, 900);

      final count = jobs.length;
      controller.setViewport(const Size(900.4, 900)); // sub-pixel change: ignored
      async.elapse(const Duration(milliseconds: 20));
      expect(jobs.length, count);
    });
  });

  // Galaxy S24 Ultra: 1440x3120 (QHD+) and 1080x2340 (FHD+, the default).
  for (final (label, size, dpr) in [
    ('QHD+', const Size(1440, 3120), 3.75),
    ('FHD+', const Size(1080, 2340), 2.8125),
  ]) {
    for (final (orientation, photo) in [('portrait', (3000, 4000)), ('landscape', (4000, 3000))]) {
      testWidgets('S24 Ultra $label, $orientation photo: preview drawn 1:1 with screen pixels', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = dpr;
        addTearDown(tester.view.reset);
        final app = TestApp(
          image: LoadedImage(name: 'photo.jpg', image: gradient(photo.$1, photo.$2)),
        );
        await tester.pumpWidget(app.build());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open...'));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(HomeScreen));
        final filter = Provider.of<FilterController>(context, listen: false);
        final media = Provider.of<MediaModel>(context, listen: false);
        final output = filter.result!.output;
        final viewport = filter.viewport!;

        // The render fills the canvas (in physical pixels) with the photo's shape...
        expect(output.width <= viewport.width && output.height <= viewport.height, isTrue);
        expect(
          output.width == viewport.width.floor() || output.height == viewport.height.floor(),
          isTrue,
        );
        expect(
          output.width / output.height,
          closeTo(media.preview!.width / media.preview!.height, 0.01),
        );
        // ...and is laid out at exactly one image pixel per screen pixel.
        final view = find.byKey(const Key('preview-image'));
        expect(identical(tester.widget<RgbImageView>(view).image, output), isTrue);
        final drawn = tester.getSize(find.descendant(of: view, matching: find.byType(RawImage)));
        expect(drawn.width * dpr, closeTo(output.width, 0.01));
        expect(drawn.height * dpr, closeTo(output.height, 0.01));
      });
    }
  }
}
