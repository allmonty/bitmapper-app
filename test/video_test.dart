import 'dart:async';

import 'package:bitmapper/models/editor_model.dart';
import 'package:bitmapper/models/media_model.dart';
import 'package:bitmapper/screens/home_screen.dart';
import 'package:bitmapper/services/animation_exporter.dart';
import 'package:bitmapper/services/filter_controller.dart';
import 'package:bitmapper/services/gif_io.dart';
import 'package:bitmapper/services/image_loader.dart';
import 'package:bitmapper/services/video_exporter.dart';
import 'package:bitmapper/widgets/pixel_grid_view.dart';
import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import 'helpers.dart';

void main() {
  const pick = LoadedVideo(name: 'clip.mp4', path: '/videos/clip.mp4');

  group('MediaModel with video', () {
    test('opens at preview size and shows the first frame', () async {
      final io = FakeVideoIO(width: 2000, height: 1000, frameCount: 90);
      final model = MediaModel(FakeImageLoader(result: pick), videoIO: io);
      expect(await model.load(MediaRequest.library), isTrue);
      expect(model.kind, MediaKind.video);
      expect(model.isSequence, isTrue);
      expect(io.opened.single, ('/videos/clip.mp4', 1024));
      expect(model.preview!.width, 1024);
      expect(model.frameCount, 90);
      expect(model.videoPath, '/videos/clip.mp4');
      expect(model.document, isNotNull);
    });

    test('cancelling the picker keeps the current media', () async {
      final model = MediaModel(FakeImageLoader(), videoIO: FakeVideoIO());
      model.setImage('a.png', gradient(8, 8));
      expect(await model.load(MediaRequest.library), isFalse);
      expect(model.kind, MediaKind.still);
    });

    test('an unreadable video throws and keeps the current media', () async {
      final io = FakeVideoIO()..openError = Exception('bad codec');
      final model = MediaModel(FakeImageLoader(result: pick), videoIO: io);
      model.setImage('a.png', gradient(8, 8));
      await expectLater(model.load(MediaRequest.library), throwsException);
      expect(model.kind, MediaKind.still);
      expect(model.loading, isFalse);
    });

    test('scrubbing fetches frames; the latest request wins', () async {
      final io = FakeVideoIO(frameCount: 60);
      final model = MediaModel(FakeImageLoader(result: pick), videoIO: io);
      await model.load(MediaRequest.library);
      model.setFrame(10);
      model.setFrame(20);
      model.setFrame(30); // 20 is superseded before it starts
      expect(model.currentFrame, 30);
      await pumpEventQueue();
      expect(model.preview!.data, RgbImage.fromRgba(64, 48, io.frameRgba(64, 48, 30)).data);
      model.setFrame(1000);
      expect(model.currentFrame, 59);
    });

    test('a failed frame doesn\'t block the next request, and can be retried', () async {
      final io = FakeVideoIO(frameCount: 60);
      final model = MediaModel(FakeImageLoader(result: pick), videoIO: io);
      await model.load(MediaRequest.library);
      io.beforeFrameAt = (t) async {
        if (t == model.frameTime(10)) throw Exception('decoder hiccup');
      };
      model.setFrame(10);
      await pumpEventQueue();
      expect(model.preview!.data, isNot(RgbImage.fromRgba(64, 48, io.frameRgba(64, 48, 10)).data));
      model.setFrame(20);
      await pumpEventQueue();
      expect(model.preview!.data, RgbImage.fromRgba(64, 48, io.frameRgba(64, 48, 20)).data);

      // Frame 20 is shown; selecting it again doesn't refetch.
      final calls = io.sources.last.frameAtCalls.length;
      model.setFrame(20);
      await pumpEventQueue();
      expect(io.sources.last.frameAtCalls.length, calls);

      // A frame that failed is fetched again when re-selected.
      io.beforeFrameAt = (t) async {
        if (t == model.frameTime(30)) throw Exception('once');
      };
      model.setFrame(30);
      await pumpEventQueue();
      io.beforeFrameAt = null;
      model.setFrame(30);
      await pumpEventQueue();
      expect(model.preview!.data, RgbImage.fromRgba(64, 48, io.frameRgba(64, 48, 30)).data);
    });

    test('a frame that never arrives times out instead of blocking scrubbing', () {
      fakeAsync((async) {
        final io = FakeVideoIO(frameCount: 60);
        final model = MediaModel(FakeImageLoader(result: pick), videoIO: io);
        model.load(MediaRequest.library);
        async.flushMicrotasks();
        final never = Completer<void>();
        io.beforeFrameAt = (t) => t == model.frameTime(5) ? never.future : Future.value();
        model.setFrame(5);
        async.flushMicrotasks();
        model.setFrame(6); // queued behind the stuck frame
        async.elapse(MediaModel.frameTimeout + const Duration(seconds: 1));
        expect(model.preview!.data, RgbImage.fromRgba(64, 48, io.frameRgba(64, 48, 6)).data);
      });
    });

    test('palette samples are decoded once per count and cached', () async {
      final io = FakeVideoIO(frameCount: 30);
      final model = MediaModel(FakeImageLoader(result: pick), videoIO: io);
      await model.load(MediaRequest.library);
      expect(model.paletteSamples(4), isNull);
      expect(model.sampling, isTrue);
      await pumpEventQueue();
      final samples = model.paletteSamples(4)!;
      expect(samples, hasLength(4));
      expect(model.sampling, isFalse);
      expect(identical(model.paletteSamples(4), samples), isTrue);
      expect(model.frameTime(15), const Duration(milliseconds: 500));
    });

    test('loading something else closes the video', () async {
      final io = FakeVideoIO();
      final model = MediaModel(FakeImageLoader(result: pick), videoIO: io);
      await model.load(MediaRequest.library);
      model.setImage('a.png', gradient(8, 8));
      expect(model.isVideo, isFalse);
      expect(model.videoPath, isNull);
    });
  });

  group('exportVideo', () {
    const config = BitmapFilterConfig(
      gridCols: 16,
      gridRows: 12,
      bitDepth: 3,
      dither: 'ordered',
      paletteStrategy: PaletteStrategy.firstFrame,
    );

    test('MP4: every frame, at the video size, with audio and one palette', () async {
      final io = FakeVideoIO(width: 65, height: 48, frameCount: 12);
      final source = await io.open('/in.mp4');
      final first = await source.frameAt(Duration.zero);
      final progress = <int>[];
      final result = await exportVideo(
        VideoExportJob(
          inputPath: '/in.mp4',
          outputPath: '/tmp/out.mp4',
          config: config,
          paletteFrames: [RgbImage.fromRgba(first.width, first.height, first.rgba)],
          format: VideoFormat.mp4,
          mp4Resolution: Mp4Resolution.p720,
        ),
        io,
        onProgress: (d, _) => progress.add(d),
      );
      expect(result.path, '/tmp/out.mp4');
      expect(result.frames, 12);
      expect(progress.last, 12);
      expect(io.opened.last, ('/in.mp4', 1280));
      final sink = io.sinks.single;
      expect(sink.finished, isTrue);
      expect(sink.audioSourcePath, '/in.mp4');
      expect((sink.width, sink.height), (64, 48));
      expect(sink.frames, hasLength(12));
      expect(sink.frames[3].$2, const Duration(microseconds: 100000));
      final all = sink.frames.expand((f) => colorSet(f.$1, stride: 4)).toSet();
      expect(all.length, lessThanOrEqualTo(8), reason: 'one 3-bit palette for every frame');
    });

    test('MP4 with sound the MP4 can\'t hold: saved silent and reported', () async {
      final io = FakeVideoIO(frameCount: 3, audioCompatible: false);
      final result = await exportVideo(
        const VideoExportJob(
          inputPath: '/in.mov',
          outputPath: '/o.mp4',
          config: config,
          paletteFrames: [],
          format: VideoFormat.mp4,
        ),
        io,
      );
      expect(io.sinks.single.finished, isTrue);
      expect(io.sinks.single.frames, hasLength(3));
      expect(result.audioDropped, isTrue);
    });

    test('compatible sound is kept', () async {
      final io = FakeVideoIO(frameCount: 2);
      final result = await exportVideo(
        const VideoExportJob(
          inputPath: '/in.mp4',
          outputPath: '/o.mp4',
          config: config,
          paletteFrames: [],
          format: VideoFormat.mp4,
        ),
        io,
      );
      expect(result.audioDropped, isFalse);
    });

    test('MP4 without audio passes no audio source', () async {
      final io = FakeVideoIO(frameCount: 2, hasAudio: false);
      await exportVideo(
        const VideoExportJob(
          inputPath: '/in.mp4',
          outputPath: '/o.mp4',
          config: config,
          paletteFrames: [],
          format: VideoFormat.mp4,
        ),
        io,
      );
      expect(io.sinks.single.audioSourcePath, isNull);
    });

    test('cancelling deletes the partial MP4 and closes the reader', () async {
      final io = FakeVideoIO(frameCount: 20);
      var done = 0;
      await expectLater(
        exportVideo(
          const VideoExportJob(
            inputPath: '/in.mp4',
            outputPath: '/o.mp4',
            config: config,
            paletteFrames: [],
            format: VideoFormat.mp4,
          ),
          io,
          onProgress: (d, _) => done = d,
          isCancelled: () => done >= 5,
        ),
        throwsA(isA<ExportCancelled>()),
      );
      expect(io.sinks.single.cancelled, isTrue);
      expect(io.sinks.single.finished, isFalse);
    });

    test('GIF: frames sampled down to the GIF frame rate, sized per cell', () async {
      final io = FakeVideoIO(frameCount: 30, frameRate: 30); // 1 second
      final result = await exportVideo(
        const VideoExportJob(
          inputPath: '/in.mp4',
          outputPath: '/unused.mp4',
          config: config,
          paletteFrames: [],
          format: VideoFormat.gif,
          gifSize: GifSizePerCell(2),
          gifFrameRate: 10,
        ),
        io,
      );
      expect(io.sinks, isEmpty);
      expect(io.opened.last.$2, kMaxAnimationDimension);
      final back = decodeGif(result.gifBytes!)!;
      expect(result.frames, 10);
      expect(back.frameCount, 10);
      expect((back.width, back.height), (32, 24));
      expect(back.durationsMs.toSet(), {100});
    });
  });

  group('video UI', () {
    T read<T>(WidgetTester tester) =>
        Provider.of<T>(tester.element(find.byType(HomeScreen)), listen: false);

    Future<TestApp> openVideo(WidgetTester tester) async {
      usePhoneScreen(tester);
      final app = TestApp()..loader.result = pick;
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open...'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('opening a video shows the scrubber and export options', (tester) async {
      await openVideo(tester);
      expect(find.text('Bitmapper - clip.mp4'), findsOneWidget);
      expect(find.text('Frame 1 / 30'), findsOneWidget);
      expect(find.byKey(const Key('preview-image')), findsOneWidget);
      await tester.tap(find.text('Animation'));
      await tester.pumpAndSettle();
      final mp4 = find.text('MP4 video (with sound)');
      await tester.ensureVisible(mp4);
      await tester.pumpAndSettle();
      expect(mp4, findsOneWidget);
      expect(find.text('720p'), findsOneWidget);
    });

    testWidgets('a video whose sound can\'t be kept warns on load, in the tab and after saving', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final app = TestApp()..loader.result = pick;
      app.videoIO.audioCompatible = false;
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open...'));
      await tester.pumpAndSettle();
      expect(find.textContaining("can't be copied into an MP4"), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Animation'));
      await tester.pumpAndSettle();
      final note = find.text("This video's sound can't be kept; the MP4 will be silent.");
      await tester.ensureVisible(note);
      expect(note, findsOneWidget);

      await tester.tap(find.text('File'));
      await tester.pump();
      await tester.tap(find.text('Save as...'));
      await tester.pumpAndSettle();
      expect(app.saver.savedFiles, hasLength(1));
      expect(find.text('Saved bitmapper_1234.mp4 (without sound)'), findsOneWidget);
    });

    testWidgets('videos with compatible or no sound don\'t warn', (tester) async {
      await openVideo(tester);
      expect(find.textContaining("can't be copied into an MP4"), findsNothing);
      await tester.tap(find.text('Animation'));
      await tester.pumpAndSettle();
      expect(find.textContaining("sound can't be kept"), findsNothing);
      expect(find.text('Animated GIF (no sound)'), findsOneWidget);
    });

    testWidgets('File > Open... opens a video picked from the library', (tester) async {
      usePhoneScreen(tester);
      final app = TestApp()..loader.result = pick;
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('File'));
      await tester.pump();
      await tester.tap(
        find.descendant(of: find.byType(Win98MenuPanel), matching: find.text('Open...')),
      );
      await tester.pumpAndSettle();
      expect(app.loader.calls, [MediaRequest.library]);
      expect(app.videoIO.opened.single.$1, '/videos/clip.mp4');
      expect(find.text('Bitmapper - clip.mp4'), findsOneWidget);
    });

    testWidgets('a bad video shows a message box', (tester) async {
      usePhoneScreen(tester);
      final app = TestApp()..loader.result = pick;
      app.videoIO.openError = Exception('bad codec');
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open...'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't open that file."), findsOneWidget);
    });

    testWidgets('Save as writes an MP4 and hands the file to the save dialog', (tester) async {
      final app = await openVideo(tester);
      await tester.tap(find.text('File'));
      await tester.pump();
      await tester.tap(find.text('Save as...'));
      await tester.pump();
      expect(find.text('Saving video'), findsOneWidget);
      await tester.pumpAndSettle();
      final sink = app.videoIO.sinks.single;
      expect(sink.finished, isTrue);
      expect(sink.frames, hasLength(30));
      final (path, name, mime) = app.saver.savedFiles.single;
      expect(path, sink.path);
      expect(name, 'bitmapper_1234.mp4');
      expect(mime, 'video/mp4');
      expect(find.text('Saved bitmapper_1234.mp4'), findsOneWidget);
    });

    testWidgets('Save as GIF when the GIF format is chosen', (tester) async {
      final app = await openVideo(tester);
      read<EditorModel>(tester).setVideoFormat(VideoFormat.gif);
      await tester.pump();
      await tester.tap(find.text('File'));
      await tester.pump();
      await tester.tap(find.text('Save as...'));
      await tester.pumpAndSettle();
      expect(app.videoIO.sinks, isEmpty);
      final (bytes, name, mime) = app.saver.saved.single;
      expect(mime, 'image/gif');
      expect(name, 'bitmapper_1234.gif');
      expect(decodeGif(bytes)!.frameCount, 15, reason: '1 s of video at 15 fps');
    });

    testWidgets('scrubbing updates the picture while palette samples are still decoding', (
      tester,
    ) async {
      final app = await openVideo(tester);
      final media = read<MediaModel>(tester);
      // Ask for a new sample count and hold its decoding back.
      final gate = Completer<void>();
      app.videoIO.beforeFrameAt = (t) =>
          media.sampling && !gate.isCompleted ? gate.future : Future.value();
      read<EditorModel>(tester).setPaletteSamples(5);
      await tester.pump();
      expect(media.sampling, isTrue);
      expect(find.text('Sampling frames...'), findsOneWidget);

      media.setFrame(20);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final filter = read<FilterController>(tester);
      final shown = tester.widget<PixelGridView>(find.byKey(const Key('preview-image'))).grid;
      expect(identical(shown, filter.result?.grid), isTrue);
      // The rendered grid has the frame's shape (square cells).
      final grid = filter.result!.grid;
      expect(grid.width / grid.height, closeTo(media.preview!.width / media.preview!.height, 0.02));
      expect(media.currentFrame, 20);

      gate.complete();
      await tester.pumpAndSettle();
      expect(media.sampling, isFalse);
    });

    testWidgets('scrubbing a video fetches the frame', (tester) async {
      await openVideo(tester);
      final scrubber = find.byType(Win98Slider).first;
      final rect = tester.getRect(scrubber);
      await tester.tapAt(Offset(rect.right - 7, rect.center.dy));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(read<MediaModel>(tester).currentFrame, 29);
      expect(find.text('Frame 30 / 30'), findsOneWidget);
    });
  });
}
