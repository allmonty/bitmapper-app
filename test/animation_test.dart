import 'dart:async';

import 'package:bitmapper/models/editor_model.dart';
import 'package:bitmapper/models/media_model.dart';
import 'package:bitmapper/services/animation_exporter.dart';
import 'package:bitmapper/services/filter_controller.dart';
import 'package:bitmapper/services/gif_io.dart';
import 'package:bitmapper/services/image_loader.dart';
import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

LoadedAnimation loadedGif({int n = 4}) {
  final bytes = makeGif(n: n);
  return LoadedAnimation(name: 'clip.gif', bytes: bytes, animation: decodeGif(bytes)!);
}

void main() {
  group('MediaModel with animations', () {
    test('loads an animation and scrubs frames', () async {
      final model = MediaModel(FakeImageLoader(result: loadedGif(n: 4)));
      await model.load(MediaRequest.library);
      expect(model.kind, MediaKind.animation);
      expect(model.isAnimation, isTrue);
      expect(model.frameCount, 4);
      expect(model.currentFrame, 0);
      expect(model.full, isNull);
      expect(identical(model.preview, model.animation!.frames[0]), isTrue);

      var notified = 0;
      model.addListener(() => notified++);
      model.setFrame(2);
      expect(identical(model.preview, model.animation!.frames[2]), isTrue);
      model.setFrame(99);
      expect(model.currentFrame, 3);
      model.setFrame(3);
      expect(notified, 2, reason: 'setting the same frame does not notify');
    });

    test('loading a still after an animation resets it', () async {
      final loader = FakeImageLoader(result: loadedGif());
      final model = MediaModel(loader);
      await model.load(MediaRequest.library);
      model.setFrame(2);
      loader.result = LoadedImage(name: 'a.png', image: gradient(10, 10));
      await model.load(MediaRequest.library);
      expect(model.kind, MediaKind.still);
      expect(model.animation, isNull);
      expect(model.animationBytes, isNull);
      expect(model.currentFrame, 0);
      expect(model.frameCount, 1);
    });

    test('loadMedia dispatches the same way load() does, for already-picked media', () async {
      final model = MediaModel(FakeImageLoader());

      await model.loadMedia(LoadedImage(name: 'a.png', image: gradient(10, 10)));
      expect(model.kind, MediaKind.still);
      expect(model.name, 'a.png');

      await model.loadMedia(loadedGif(n: 3));
      expect(model.kind, MediaKind.animation);
      expect(model.frameCount, 3);
    });
  });

  testWidgets('decodeMedia: animated GIFs become animations, 1-frame GIFs stills', (tester) async {
    final anim = (await tester.runAsync(() => decodeMedia('a.gif', makeGif(n: 3))))!;
    expect(anim, isA<LoadedAnimation>());
    expect((anim as LoadedAnimation).animation.frameCount, 3);
    final still = (await tester.runAsync(() => decodeMedia('b.gif', makeGif(n: 1))))!;
    expect(still, isA<LoadedImage>());
    expect((still as LoadedImage).image.width, 40);
  });

  group('EditorModel animation settings', () {
    test('strategy, samples, noise, frame skip and GIF size', () {
      final editor = EditorModel();
      editor.setPaletteStrategy(PaletteStrategy.perFrame);
      editor.setPaletteSamples(100);
      editor.setAnimateNoise(true);
      editor.setFrameSkip(3);
      editor.setGifSize(const GifSizeOriginal());
      expect(editor.config.paletteStrategy, PaletteStrategy.perFrame);
      expect(editor.config.paletteSamples, kMaxPaletteSamples);
      expect(editor.config.animateNoise, isTrue);
      expect(editor.config.frameSkip, 3);
      expect(editor.gifSize, const GifSizeOriginal());

      editor.setFrameSkip(100);
      expect(editor.config.frameSkip, kMaxFrameSkip);
      editor.setFrameSkip(-5);
      expect(editor.config.frameSkip, kMinFrameSkip);
    });

    test('animation-friendly settings are offered, not forced', () {
      final editor = EditorModel(); // default dither is Floyd–Steinberg
      expect(editor.isErrorDiffusion, isTrue);
      expect(editor.isAnimationFriendly, isFalse);
      editor.applyAnimationFriendly();
      expect(editor.config.dither, 'ordered');
      expect(editor.config.paletteStrategy, PaletteStrategy.sampled);
      expect(editor.isAnimationFriendly, isTrue);
      editor.setDither('atkinson'); // still the user's choice afterwards
      expect(editor.config.dither, 'atkinson');
    });
  });

  group('FilterController shared palette', () {
    final frames = decodeGif(makeGif(n: 6))!.frames;
    const config = BitmapFilterConfig(gridCols: 8, gridRows: 6, bitDepth: 2, paletteSamples: 3);

    test('built once, reused while scrubbing and for post-palette tweaks', () {
      fakeAsync((async) {
        final jobs = <FilterJob>[];
        final controller = FilterController(
          runner: (job) async {
            jobs.add(job);
            return runFilterJob(job);
          },
          debounce: const Duration(milliseconds: 10),
        );
        void render(int frame, BitmapFilterConfig c) {
          controller.request(
            frames[frame],
            c,
            animation: AnimationContext(frames: frames, frameIndex: frame),
          );
          async.elapse(const Duration(milliseconds: 20));
        }

        render(0, config);
        expect(jobs.last.paletteFrames, hasLength(3), reason: 'sampled strategy, 3 samples');
        final first = controller.result!;

        render(4, config);
        expect(jobs.last.paletteFrames, isNull);
        expect(jobs.last.palette, first.palette, reason: 'cached palette reused');
        expect(controller.result!.palette, first.palette);

        render(4, config.copyWith(dither: 'atkinson', scanlines: 0.5, outline: 0.6));
        expect(
          jobs.last.palette,
          first.palette,
          reason: 'dither, scanlines and outline keep the palette',
        );

        render(4, config.copyWith(despeckle: true));
        expect(jobs.last.palette, first.palette, reason: 'despeckle keeps the palette');

        render(4, config.copyWith(shadeBands: 3));
        expect(jobs.last.paletteFrames, isNotNull, reason: 'shade bands change the palette');

        render(4, config.copyWith(bitDepth: 3));
        expect(jobs.last.paletteFrames, isNotNull, reason: 'bit depth changes the palette');
      });
    });

    test('scrubbing keeps the previous result on screen', () {
      fakeAsync((async) {
        final gate = Completer<FilterResult>();
        var calls = 0;
        final controller = FilterController(
          runner: (job) {
            calls++;
            return calls == 1 ? Future.value(runFilterJob(job)) : gate.future;
          },
          debounce: const Duration(milliseconds: 10),
        );
        controller.request(
          frames[0],
          config,
          animation: AnimationContext(frames: frames, frameIndex: 0),
        );
        async.elapse(const Duration(milliseconds: 20));
        expect(controller.result, isNotNull);
        controller.request(
          frames[1],
          config,
          animation: AnimationContext(frames: frames, frameIndex: 1),
        );
        expect(controller.result, isNotNull, reason: 'same document, old frame stays visible');
      });
    });

    test('per-frame strategy and fixed palettes never share', () {
      fakeAsync((async) {
        final jobs = <FilterJob>[];
        final controller = FilterController(
          runner: (job) async {
            jobs.add(job);
            return runFilterJob(job);
          },
          debounce: const Duration(milliseconds: 10),
        );
        for (final c in [
          config.copyWith(paletteStrategy: PaletteStrategy.perFrame),
          config.copyWith(paletteMode: PaletteMode.fixed, fixedPalette: 'cga'),
        ]) {
          controller.request(
            frames[1],
            c,
            animation: AnimationContext(frames: frames, frameIndex: 1),
          );
          async.elapse(const Duration(milliseconds: 20));
          expect(jobs.last.paletteFrames, isNull);
          expect(jobs.last.palette, isNull);
        }
      });
    });
  });

  group('exportGif', () {
    final gif = makeGif(n: 5);
    const config = BitmapFilterConfig(
      gridCols: 10,
      gridRows: 8,
      bitDepth: 3,
      dither: 'ordered',
      paletteStrategy: PaletteStrategy.firstFrame,
    );

    test('filters every frame with one palette, reporting progress', () {
      final progress = <(int, int)>[];
      final result = exportGif(
        GifExportJob(gifBytes: gif, config: config, size: const GifSizePerCell(3)),
        onProgress: (d, t) => progress.add((d, t)),
      );
      expect(progress, [(1, 5), (2, 5), (3, 5), (4, 5), (5, 5)]);
      expect(result.frames, 5);
      expect(result.lossyFrames, 0);
      final back = decodeGif(result.bytes)!;
      expect(back.frameCount, 5);
      expect(back.width, 30);
      expect(back.height, 24);
      final allColors = back.frames.expand((f) => colorSet(f.data)).toSet();
      expect(allColors.length, lessThanOrEqualTo(8), reason: 'one 3-bit palette for every frame');
    });

    test('frameSkip holds a rendered frame for the skipped ones', () {
      final skipConfig = config.copyWith(frameSkip: 2);
      final result = exportGif(
        GifExportJob(gifBytes: gif, config: skipConfig, size: const GifSizePerCell(3)),
      );
      expect(
        result.frames,
        5,
        reason: 'still one output frame per source frame, same as without frameSkip',
      );
      final back = decodeGif(result.bytes)!;
      expect(back.frameCount, 5);
      // Frame 0 is rendered; 1 and 2 hold its pixels (frameSkip: 2 means
      // render, then hold for 2 more). Frame 3 is rendered fresh; 4 holds it.
      expect(back.frames[1].data, back.frames[0].data);
      expect(back.frames[2].data, back.frames[0].data);
      expect(back.frames[4].data, back.frames[3].data);
      expect(back.frames[3].data, isNot(back.frames[0].data), reason: 'distinct source frames');
      // Total (and per-frame) duration is unaffected: each output entry
      // still carries its own source frame's original delay.
      expect(back.durationsMs, decodeGif(gif)!.durationsMs);
    });

    test('original size keeps the source dimensions', () {
      final result = exportGif(
        GifExportJob(gifBytes: gif, config: config, size: const GifSizeOriginal()),
      );
      final back = decodeGif(result.bytes)!;
      expect((back.width, back.height), (40, 30));
    });

    test('cancellation stops between frames', () {
      var done = 0;
      expect(
        () => exportGif(
          GifExportJob(gifBytes: gif, config: config, size: const GifSizePerCell(1)),
          onProgress: (d, _) => done = d,
          isCancelled: () => done >= 2,
        ),
        throwsA(isA<ExportCancelled>()),
      );
      expect(done, 2);
    });

    test('runs on a worker isolate and can be cancelled', () async {
      final progress = <int>[];
      final task = exportGifInIsolate(
        GifExportJob(gifBytes: gif, config: config, size: const GifSizePerCell(2)),
        (d, _) => progress.add(d),
      );
      final result = await task.result;
      expect(result.frames, 5);
      expect(progress.last, 5);

      final cancelled = exportGifInIsolate(
        GifExportJob(
          gifBytes: makeGif(n: 30, width: 300, height: 200),
          config: config,
          size: const GifSizeOriginal(),
        ),
        (_, _) {},
      );
      cancelled.cancel();
      await expectLater(cancelled.result, throwsA(isA<ExportCancelled>()));
    });

    test('a bad file reports an error', () async {
      final task = exportGifInIsolate(
        GifExportJob(gifBytes: gradient(4, 4).data, config: config, size: const GifSizeOriginal()),
        (_, _) {},
      );
      await expectLater(task.result, throwsA(isA<StateError>()));
    });
  });
}
