@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:win98_ui/win98_ui.dart';

import 'harness.dart';

void main() {
  setUpAll(loadWin98Font);

  Future<void> pumpGolden(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(RepaintBoundary(child: child), size: size));
    await tester.pump();
  }

  testWidgets('bevel styles', (tester) async {
    await pumpGolden(
      tester,
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final style in BevelStyle.values)
            SizedBox(width: 60, height: 40, child: Bevel(style: style)),
        ],
      ),
      const Size(300, 110),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/bevels.png'));
  });

  testWidgets('controls', (tester) async {
    await pumpGolden(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Win98Button(isDefault: true, onPressed: () {}, child: const Text('OK')),
              const SizedBox(width: 6),
              Win98Button(onPressed: () {}, child: const Text('Cancel')),
              const SizedBox(width: 6),
              const Win98Button(onPressed: null, child: Text('Apply')),
            ],
          ),
          Win98Checkbox(value: true, label: 'Checked', onChanged: (_) {}),
          Win98Radio<int>(value: 1, groupValue: 1, label: 'Selected', onChanged: (_) {}),
          Win98Slider(value: 0.4, divisions: 10, onChanged: (_) {}),
          Win98Dropdown<int>(
            value: 1,
            items: const [Win98DropdownItem(value: 1, label: 'Floyd-Steinberg')],
            onChanged: (_) {},
          ),
          const SizedBox(height: 6),
          const Win98ProgressBar(value: 0.6),
        ],
      ),
      const Size(360, 280),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/controls.png'),
    );
  });

  testWidgets('window chrome with tabs', (tester) async {
    await pumpGolden(
      tester,
      Win98Window(
        title: 'Bitmapper - photo.png',
        expand: true,
        onMinimize: () {},
        onMaximize: () {},
        onClose: () {},
        menuBar: const Win98MenuBar(
          menus: [
            Win98Menu(label: 'File', items: []),
            Win98Menu(label: 'Help', items: []),
          ],
        ),
        statusBar: const Win98StatusBar(
          panes: [Win98StatusPane(Text('Ready'), flex: 2), Win98StatusPane(Text('16 colors'))],
        ),
        child: Win98TabView(
          tabs: [
            Win98Tab(
              label: 'Palette',
              builder: (_) => const Win98GroupBox(label: 'Mode', child: Text('Auto')),
            ),
            Win98Tab(label: 'Dither', builder: (_) => const SizedBox()),
          ],
        ),
      ),
      const Size(360, 260),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/window.png'));
  });
}
