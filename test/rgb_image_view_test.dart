import 'package:bitmapper/widgets/rgb_image_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  Future<RawImage> settle(WidgetTester tester) async {
    // decodeImageFromPixels completes on the real event loop.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    return tester.widget<RawImage>(find.byType(RawImage));
  }

  Widget host(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600), devicePixelRatio: 2),
      child: Center(child: child),
    ),
  );

  testWidgets('uploads the pixels at exactly the image size', (tester) async {
    final image = gradient(301, 157); // odd sizes on purpose
    await tester.pumpWidget(host(RgbImageView(image: image)));
    final raw = await settle(tester);
    expect(raw.image, isNotNull);
    expect((raw.image!.width, raw.image!.height), (301, 157));
    expect(raw.filterQuality, FilterQuality.none);
    // 1:1 with physical pixels at devicePixelRatio 2.
    expect(tester.getSize(find.byType(RawImage)), const Size(150.5, 78.5));
  });

  testWidgets('a newer image replaces the old one', (tester) async {
    await tester.pumpWidget(host(RgbImageView(image: gradient(40, 30))));
    await settle(tester);
    await tester.pumpWidget(host(RgbImageView(image: gradient(64, 20))));
    final raw = await settle(tester);
    expect((raw.image!.width, raw.image!.height), (64, 20));
  });

  testWidgets('never stretches, even when the parent forces a size', (tester) async {
    await tester.pumpWidget(
      host(SizedBox(width: 400, height: 400, child: RgbImageView(image: gradient(300, 100)))),
    );
    await settle(tester);
    expect(tester.getSize(find.byType(RawImage)), const Size(150, 50));
  });

  testWidgets('scales down to fit when bigger than the space', (tester) async {
    await tester.pumpWidget(
      host(SizedBox(width: 100, height: 100, child: RgbImageView(image: gradient(1000, 500)))),
    );
    await settle(tester);
    expect(tester.getSize(find.byType(RawImage)), const Size(100, 50));
  });
}
