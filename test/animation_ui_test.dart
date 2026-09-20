import 'package:bitmapper/models/editor_model.dart';
import 'package:bitmapper/models/media_model.dart';
import 'package:bitmapper/screens/home_screen.dart';
import 'package:bitmapper/services/gif_io.dart';
import 'package:bitmapper/services/image_loader.dart';
import 'package:bitmapper/widgets/controls/animation_tab.dart';
import 'package:bitmapper/widgets/controls/labeled_slider.dart';
import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import 'helpers.dart';

void main() {
  LoadedAnimation clip() {
    final bytes = makeGif(n: 4);
    return LoadedAnimation(name: 'clip.gif', bytes: bytes, animation: decodeGif(bytes)!);
  }

  T read<T>(WidgetTester tester) =>
      Provider.of<T>(tester.element(find.byType(HomeScreen)), listen: false);

  Future<TestApp> openClip(WidgetTester tester) async {
    usePhoneScreen(tester);
    final app = TestApp(image: clip());
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open...'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('opening a GIF shows the scrubber and the Animation tab', (tester) async {
    await openClip(tester);
    expect(find.text('Frame 1 / 4'), findsOneWidget);
    expect(find.text('Animation'), findsOneWidget);
    expect(find.byKey(const Key('preview-image')), findsOneWidget);
  });

  testWidgets('stills have no scrubber or Animation tab', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(
      TestApp(
        image: LoadedImage(name: 'a.png', image: gradient(40, 30)),
      ).build(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open...'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Frame '), findsNothing);
    expect(find.text('Animation'), findsNothing);
  });

  testWidgets('scrubbing changes the previewed frame', (tester) async {
    await openClip(tester);
    final scrubber = find.byType(Win98Slider).first;
    final rect = tester.getRect(scrubber);
    await tester.tapAt(Offset(rect.right - 7, rect.center.dy));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(read<MediaModel>(tester).currentFrame, 3);
    expect(find.text('Frame 4 / 4'), findsOneWidget);
  });

  testWidgets('error-diffusion dither shows a shimmer tip; the friendly button fixes it', (
    tester,
  ) async {
    await openClip(tester);
    expect(find.text('Dither may shimmer between frames'), findsOneWidget);
    await tester.tap(find.text('Animation'));
    await tester.pumpAndSettle();
    final button = find.text('Use animation-friendly settings');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    final config = read<EditorModel>(tester).config;
    expect(config.dither, 'ordered');
    expect(config.paletteStrategy, PaletteStrategy.sampled);
    expect(find.text('Dither may shimmer between frames'), findsNothing);
  });

  testWidgets('Animation tab changes the palette strategy and GIF size', (tester) async {
    await openClip(tester);
    await tester.tap(find.text('Animation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First frame'));
    await tester.pump();
    expect(read<EditorModel>(tester).config.paletteStrategy, PaletteStrategy.firstFrame);
    expect(find.textContaining('Samples:'), findsNothing);

    final original = find.text('Original size (40×30)');
    await tester.ensureVisible(original);
    await tester.pumpAndSettle();
    await tester.tap(original);
    await tester.pump();
    expect(read<EditorModel>(tester).gifSize, const GifSizeOriginal());
  });

  testWidgets('Animation tab shows and updates the frame-skip label with the effective fps', (
    tester,
  ) async {
    await openClip(tester);
    await tester.tap(find.text('Animation'));
    await tester.pumpAndSettle();
    // clip() durations are 50, 100, 150, 200 ms -> average 125 ms -> 8 fps.
    expect(find.text('Skip frames: off (8 fps)'), findsOneWidget);
    read<EditorModel>(tester).setFrameSkip(3);
    await tester.pump();
    expect(find.text('Skip frames: 3 (~2 fps)'), findsOneWidget);
    expect(find.text('Skip frames: off (8 fps)'), findsNothing);
  });

  testWidgets('Animation tab has a gap before the frame-skip slider', (tester) async {
    await openClip(tester);
    await tester.tap(find.text('Animation'));
    await tester.pumpAndSettle();
    final scrollView = tester.widget<Win98ScrollView>(
      find.descendant(of: find.byType(AnimationTab), matching: find.byType(Win98ScrollView)),
    );
    final children = (scrollView.child as Column).children;
    final frameSkipIndex = children.indexWhere((w) => w is LabeledSlider);
    expect(frameSkipIndex, greaterThan(0));
    expect(identical(children[frameSkipIndex - 1], kControlGap), isTrue);
  });

  testWidgets('Save as exports every frame to an animated GIF', (tester) async {
    final app = await openClip(tester);
    await tester.tap(find.text('File'));
    await tester.pump();
    await tester.tap(find.text('Save as...'));
    await tester.pump();
    expect(find.text('Saving animation'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(app.saver.saved, hasLength(1));
    final (bytes, name, mime) = app.saver.saved.single;
    expect(mime, 'image/gif');
    expect(name, 'bitmapper_1234.gif');
    final back = decodeGif(bytes)!;
    expect(back.frameCount, 4);
    // Default GIF size: 4 px per cell over the 120-column grid (clamped to
    // the 40 px wide clip): 40x30 cells -> 160x120.
    expect((back.width, back.height), (160, 120));
    expect(find.text('Saved bitmapper_1234.gif'), findsOneWidget);
    expect(find.text('Saving animation'), findsNothing);
  });

  testWidgets('cancelling the export saves nothing', (tester) async {
    final app = await openClip(tester);
    await tester.tap(find.text('File'));
    await tester.pump();
    await tester.tap(find.text('Save as...'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(app.saver.saved, isEmpty);
    expect(find.text('Saving animation'), findsNothing);
    expect(find.text('Ready'), findsNothing); // still shows the shimmer tip
  });
}
