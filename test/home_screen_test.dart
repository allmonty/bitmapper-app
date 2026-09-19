import 'package:bitmapper/models/editor_model.dart';
import 'package:bitmapper/screens/home_screen.dart';
import 'package:bitmapper/services/filter_controller.dart';
import 'package:bitmapper/services/image_loader.dart';
import 'package:bitmapper/widgets/pixel_grid_view.dart';
import 'package:bitmapper/widgets/rgb_image_view.dart';
import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import 'helpers.dart';

void main() {
  LoadedImage photo() => LoadedImage(name: 'photo.jpg', image: gradient(400, 300));

  EditorModel editorOf(WidgetTester tester) =>
      Provider.of<EditorModel>(tester.element(find.byType(HomeScreen)), listen: false);

  Future<void> pumpApp(
    WidgetTester tester,
    TestApp app, {
    Locale locale = const Locale('en'),
  }) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(app.build(locale: locale));
    await tester.pumpAndSettle();
  }

  /// Load the fake photo and let the debounced preview render.
  Future<void> openPhoto(WidgetTester tester) async {
    await tester.tap(find.text('Open...'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String menu, String item) async {
    await tester.tap(find.text(menu).first); // the menu bar precedes the tabs
    await tester.pump();
    // Scoped to the open menu: items like "Open..." also label buttons.
    await tester.tap(find.descendant(of: find.byType(Win98MenuPanel), matching: find.text(item)));
    await tester.pump();
  }

  testWidgets('shows the empty state before an image is loaded', (tester) async {
    await pumpApp(tester, TestApp());
    expect(find.text('Bitmapper - (untitled)'), findsOneWidget);
    expect(find.text('Open a photo or video'), findsOneWidget);
    expect(find.text('No image'), findsOneWidget);
    expect(find.byKey(const Key('preview-image')), findsNothing);
    expect(find.text('Palette'), findsOneWidget);
  });

  testWidgets('loading an image renders the preview and fills the status bar', (tester) async {
    final app = TestApp(image: photo());
    await pumpApp(tester, app);
    await openPhoto(tester);

    expect(app.loader.calls, [MediaRequest.library]);
    expect(find.text('Bitmapper - photo.jpg'), findsOneWidget);
    expect(find.byKey(const Key('preview-image')), findsOneWidget);
    expect(find.text('120×90 cells'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+ colors$')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+ ms$')), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('Open... picks from the library (photos and videos)', (tester) async {
    final app = TestApp(image: photo());
    await pumpApp(tester, app);
    await tester.tap(find.text('Open...'));
    await tester.pumpAndSettle();
    expect(app.loader.calls, [MediaRequest.library]);
  });

  group('Camera...', () {
    Future<TestApp> chooseInCamera(WidgetTester tester, String? choice) async {
      final app = TestApp(image: photo());
      await pumpApp(tester, app);
      await tester.tap(find.text('Camera...'));
      await tester.pumpAndSettle();
      expect(find.text('Take a photo or record a video?'), findsOneWidget);
      await tester.tap(find.text(choice ?? 'Cancel'));
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('Photo takes a picture', (tester) async {
      final app = await chooseInCamera(tester, 'Photo');
      expect(app.loader.calls, [MediaRequest.cameraPhoto]);
    });

    testWidgets('Video records a video', (tester) async {
      final app = await chooseInCamera(tester, 'Video');
      expect(app.loader.calls, [MediaRequest.cameraVideo]);
    });

    testWidgets('Cancel opens nothing', (tester) async {
      final app = await chooseInCamera(tester, null);
      expect(app.loader.calls, isEmpty);
      expect(find.text('Open a photo or video'), findsOneWidget);
    });

    testWidgets('is in the File menu too', (tester) async {
      final app = TestApp(image: photo());
      await pumpApp(tester, app);
      await openMenu(tester, 'File', 'Camera...');
      await tester.pumpAndSettle();
      expect(find.text('Take a photo or record a video?'), findsOneWidget);
      expect(app.loader.calls, isEmpty);
    });
  });

  testWidgets('a load error shows a message box', (tester) async {
    final app = TestApp()..loader.error = Exception('corrupt');
    await pumpApp(tester, app);
    await tester.tap(find.text('Open...'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open that file."), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open that file."), findsNothing);
    expect(find.text('Open a photo or video'), findsOneWidget);
  });

  testWidgets('switching to a fixed palette and picking one updates the config', (tester) async {
    await pumpApp(tester, TestApp(image: photo()));
    await openPhoto(tester);

    await tester.tap(find.text('Fixed'));
    await tester.pump();
    expect(editorOf(tester).config.paletteMode, PaletteMode.fixed);
    await tester.tap(find.text('PICO-8 (16)'));
    await tester.pump();
    // The list is long (27 palettes): scroll to the entry first.
    await tester.ensureVisible(find.text('Game Boy (4)'));
    await tester.pump();
    await tester.tap(find.text('Game Boy (4)'));
    await tester.pumpAndSettle();
    expect(editorOf(tester).config.fixedPalette, 'gameboy');
  });

  testWidgets('bit depth slider reaches 12 bits and then true color', (tester) async {
    await pumpApp(tester, TestApp());
    final slider = find.byType(Win98Slider); // the only slider on the Palette tab
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final rect = tester.getRect(slider);
    // The last notch is true color; the one before it is 12 bits.
    await tester.tapAt(Offset(rect.right - 7, rect.center.dy));
    await tester.pump();
    expect(editorOf(tester).trueColor, isTrue);
    expect(find.text('True color (no quantizing)'), findsOneWidget);
    final notch = (rect.width - 14) / 12;
    await tester.tapAt(Offset(rect.right - 7 - notch, rect.center.dy));
    await tester.pump();
    expect(editorOf(tester).config.bitDepth, 12);
    expect(find.text('Bit depth: 12 (4096 colors)'), findsOneWidget);
  });

  testWidgets('dither tab changes the method', (tester) async {
    await pumpApp(tester, TestApp());
    await tester.tap(find.text('Dither'));
    await tester.pump();
    await tester.tap(find.text('Floyd–Steinberg'));
    await tester.pump();
    await tester.tap(find.text('Atkinson'));
    await tester.pumpAndSettle();
    expect(editorOf(tester).config.dither, 'atkinson');
  });

  testWidgets('applying a built-in preset from the presets tab', (tester) async {
    await pumpApp(tester, TestApp());
    await tester.tap(find.text('Presets').last);
    await tester.pump();
    await tester.ensureVisible(find.text('VHS (built-in)'));
    await tester.pump();
    await tester.tap(find.text('VHS (built-in)'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Apply'));
    await tester.pump();
    final config = editorOf(tester).config;
    expect(config.bitDepth, 5);
    expect(config.scanlines, 0.25);
    expect(config.gridCols, kDefaultConfig.gridCols);
  });

  testWidgets('applying a preset from the Presets menu', (tester) async {
    await pumpApp(tester, TestApp());
    await openMenu(tester, 'Presets', 'Game Boy Camera');
    expect(editorOf(tester).config.fixedPalette, 'gameboy');
  });

  testWidgets('the Effects tab outline slider outlines the preview grid', (tester) async {
    await pumpApp(tester, TestApp(image: photo()));
    await openPhoto(tester);
    final filter = Provider.of<FilterController>(
      tester.element(find.byType(HomeScreen)),
      listen: false,
    );
    final before = filter.result!.grid;
    await tester.tap(find.text('Effects'));
    await tester.pumpAndSettle();
    final slider = find.byType(Win98Slider).at(2); // scanlines, shade bands, outline
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.right - 7, rect.center.dy));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(editorOf(tester).config.outline, 1.0);
    expect(find.text('Outline: 100%'), findsOneWidget);
    expect(filter.result!.grid.data, isNot(before.data), reason: 'edges got inked');
  });

  testWidgets('the Toon controls set shade bands and cleanup', (tester) async {
    await pumpApp(tester, TestApp(image: photo()));
    await openPhoto(tester);
    await tester.tap(find.text('Effects'));
    await tester.pumpAndSettle();
    expect(find.text('Shade bands: off'), findsOneWidget);
    final bands = find.byType(Win98Slider).at(1);
    final rect = tester.getRect(bands);
    await tester.tapAt(Offset(rect.right - 7, rect.center.dy));
    await tester.pump();
    expect(editorOf(tester).config.shadeBands, 8);
    expect(find.text('Shade bands: 8'), findsOneWidget);
    await tester.tapAt(Offset(rect.left + 7, rect.center.dy));
    await tester.pump();
    expect(editorOf(tester).config.shadeBands, 0);

    await tester.tap(find.text('Clean up stray pixels'));
    await tester.pump();
    expect(editorOf(tester).config.despeckle, isTrue);
  });

  testWidgets('the Pixel Art preset switches to its chunky grid', (tester) async {
    await pumpApp(tester, TestApp(image: photo()));
    await openPhoto(tester);
    expect(find.text('120×90 cells'), findsOneWidget);
    await openMenu(tester, 'Presets', 'Pixel Art');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(editorOf(tester).columns, 64);
    expect(find.text('64×48 cells'), findsOneWidget);
  });

  testWidgets('saving, renaming and deleting a user preset', (tester) async {
    final app = TestApp();
    await pumpApp(tester, app);
    editorOf(tester).setDither('stucki');
    await tester.tap(find.text('Presets').last);
    await tester.pump();

    await tester.tap(find.text('Save current...'));
    await tester.pumpAndSettle();
    expect(find.text('Save preset'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Crunchy');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Crunchy'), findsOneWidget);
    final saved = await app.repository.load();
    expect(saved.single.name, 'Crunchy');
    expect(saved.single.config.dither, 'stucki');

    await tester.tap(find.text('Crunchy'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Rename...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Crispy');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Crispy'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Crispy"?'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Crispy'), findsNothing);
    expect(await app.repository.load(), isEmpty);
  });

  testWidgets('built-in presets cannot be renamed or deleted', (tester) async {
    await pumpApp(tester, TestApp());
    await tester.tap(find.text('Presets').last);
    await tester.pump();
    await tester.ensureVisible(find.text('VHS (built-in)'));
    await tester.pump();
    await tester.tap(find.text('VHS (built-in)'));
    await tester.pump(const Duration(milliseconds: 400));
    Win98Button button(String label) => tester.widget<Win98Button>(
      find.ancestor(of: find.text(label), matching: find.byType(Win98Button)),
    );
    expect(button('Apply').enabled, isTrue);
    expect(button('Rename...').enabled, isFalse);
    expect(button('Delete').enabled, isFalse);
  });

  testWidgets('Save as renders full size and hands a PNG to the saver', (tester) async {
    final app = TestApp(image: photo());
    await pumpApp(tester, app);
    await openPhoto(tester);

    await openMenu(tester, 'File', 'Save as...');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(app.saver.saved, hasLength(1));
    final (png, name, mime) = app.saver.saved.single;
    expect(mime, 'image/png');
    expect(name, 'bitmapper_1234.png');
    expect(png.sublist(0, 4), [137, 80, 78, 71]);
    expect(find.text('Saved bitmapper_1234.png'), findsOneWidget);
    expect(find.text('Saving'), findsNothing, reason: 'progress dialog closed');
  });

  testWidgets('a save error shows a message box', (tester) async {
    final app = TestApp(image: photo())..saver.error = Exception('disk full');
    await pumpApp(tester, app);
    await openPhoto(tester);
    await openMenu(tester, 'File', 'Save as...');
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save the image."), findsOneWidget);
  });

  testWidgets('Save as is disabled without an image', (tester) async {
    final app = TestApp();
    await pumpApp(tester, app);
    await openMenu(tester, 'File', 'Save as...');
    expect(app.saver.saved, isEmpty);
    expect(find.text('Save as...'), findsOneWidget, reason: 'disabled item keeps the menu open');
  });

  testWidgets('closing the window clears the image', (tester) async {
    await pumpApp(tester, TestApp(image: photo()));
    await openPhoto(tester);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Open a photo or video'), findsOneWidget);
    expect(find.text('Bitmapper - (untitled)'), findsOneWidget);
  });

  testWidgets('holding the preview shows the original', (tester) async {
    await pumpApp(tester, TestApp(image: photo()));
    await openPhoto(tester);
    final view = find.byKey(const Key('preview-image'));
    expect(tester.widget<PixelGridView>(view).original, isNull);
    final gridRect = tester.getRect(view);
    final gesture = await tester.startGesture(tester.getCenter(view));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<PixelGridView>(view).original, isNotNull);
    expect(find.byType(RgbImageView), findsOneWidget);
    expect(find.text('< Hold to compare'), findsOneWidget);
    expect(tester.getRect(view), gridRect, reason: 'the original shows in the same place');
    await gesture.up();
    await tester.pump();
    expect(tester.widget<PixelGridView>(view).original, isNull);
    expect(find.byType(RgbImageView), findsNothing);
  });

  testWidgets('changing a setting re-renders the preview', (tester) async {
    await pumpApp(tester, TestApp(image: photo()));
    await openPhoto(tester);
    editorOf(tester).setColumns(40);
    await tester.pump();
    expect(find.text('Working...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('40×30 cells'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('About box from the Help menu', (tester) async {
    await pumpApp(tester, TestApp());
    await openMenu(tester, 'Help', 'About Bitmapper...');
    await tester.pumpAndSettle();
    expect(find.textContaining('retro pixel-art photo filter'), findsOneWidget);
  });

  testWidgets('landscape layout puts preview and controls side by side', (tester) async {
    tester.view.physicalSize = const Size(2340, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestApp().build());
    await tester.pumpAndSettle();
    final empty = tester.getRect(find.text('Open a photo or video'));
    final tabs = tester.getRect(find.text('Palette'));
    expect(tabs.left, greaterThan(empty.right));
  });

  testWidgets('is localized in Portuguese', (tester) async {
    await pumpApp(tester, TestApp(), locale: const Locale('pt'));
    expect(find.text('Arquivo'), findsOneWidget);
    expect(find.text('Abra uma foto ou vídeo'), findsOneWidget);
    expect(find.text('Paleta'), findsOneWidget);
  });
}
