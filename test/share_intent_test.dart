import 'package:bitmapper/models/media_model.dart';
import 'package:bitmapper/screens/home_screen.dart';
import 'package:bitmapper/services/gif_io.dart';
import 'package:bitmapper/services/image_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  MediaModel mediaOf(WidgetTester tester) =>
      Provider.of<MediaModel>(tester.element(find.byType(HomeScreen)), listen: false);

  testWidgets('media shared before the app started loads on cold start', (tester) async {
    final app = TestApp();
    app.shareSource.initial = LoadedImage(name: 'shared.png', image: gradient(10, 10));
    usePhoneScreen(tester);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    expect(mediaOf(tester).name, 'shared.png');
  });

  testWidgets('media shared while the app is running loads live', (tester) async {
    final app = TestApp();
    usePhoneScreen(tester);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    expect(mediaOf(tester).hasImage, isFalse);

    app.shareSource.share(LoadedImage(name: 'live.png', image: gradient(8, 8)));
    await tester.pumpAndSettle();

    expect(mediaOf(tester).name, 'live.png');
  });

  testWidgets('a share is ignored while an export is in progress', (tester) async {
    final bytes = makeGif(n: 4);
    final app = TestApp(
      image: LoadedAnimation(name: 'clip.gif', bytes: bytes, animation: decodeGif(bytes)!),
    );
    usePhoneScreen(tester);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open...'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('File'));
    await tester.pump();
    await tester.tap(find.text('Save as...'));
    await tester.pump();
    expect(find.text('Saving animation'), findsOneWidget, reason: 'export in progress');

    app.shareSource.share(LoadedImage(name: 'ignored.png', image: gradient(4, 4)));
    await tester.pump();
    expect(mediaOf(tester).name, 'clip.gif', reason: 'share was ignored while saving');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('a shared file that fails to open shows the same error box as Open', (
    tester,
  ) async {
    final app = TestApp();
    app.videoIO.openError = Exception('bad share');
    usePhoneScreen(tester);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    app.shareSource.share(const LoadedVideo(name: 'shared.mp4', path: '/tmp/shared.mp4'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't open that file."), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(mediaOf(tester).hasImage, isFalse);
  });
}
