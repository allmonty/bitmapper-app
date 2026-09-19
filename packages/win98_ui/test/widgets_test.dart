import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:win98_ui/win98_ui.dart';

import 'harness.dart';

void main() {
  group('Win98Theme', () {
    testWidgets('falls back to defaults without an ancestor', (tester) async {
      late Win98ThemeData data;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            data = Win98Theme.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(data.face, const Color(0xFFC0C0C0));
      expect(data.desktop, const Color(0xFF008080));
    });

    testWidgets('provides overrides and a default text style', (tester) async {
      late Win98ThemeData data;
      late TextStyle style;
      await tester.pumpWidget(
        Win98Theme(
          data: const Win98ThemeData().copyWith(desktop: const Color(0xFF123456), fontSize: 20),
          child: Builder(
            builder: (context) {
              data = Win98Theme.of(context);
              style = DefaultTextStyle.of(context).style;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(data.desktop, const Color(0xFF123456));
      expect(style.fontSize, 20);
      expect(style.fontFamily, 'packages/win98_ui/PixelifySans');
    });
  });

  group('Win98Button', () {
    testWidgets('calls onPressed on tap', (tester) async {
      var taps = 0;
      await tester.pumpHarness(Win98Button(onPressed: () => taps++, child: const Text('OK')));
      await tester.tap(find.text('OK'));
      expect(taps, 1);
    });

    testWidgets('shows the pressed bevel while held', (tester) async {
      await tester.pumpHarness(Win98Button(onPressed: () {}, child: const Text('OK')));
      BevelStyle style() => tester
          .widget<Bevel>(
            find.descendant(of: find.byType(Win98Button), matching: find.byType(Bevel)).first,
          )
          .style;
      expect(style(), BevelStyle.raised);
      final gesture = await tester.startGesture(tester.getCenter(find.text('OK')));
      await tester.pump();
      expect(style(), BevelStyle.pressed);
      await gesture.up();
      await tester.pump();
      expect(style(), BevelStyle.raised);
    });

    testWidgets('disabled button ignores taps and etches its text', (tester) async {
      await tester.pumpHarness(const Win98Button(onPressed: null, child: Text('Nope')));
      await tester.tap(find.text('Nope'));
      final style = DefaultTextStyle.of(tester.element(find.text('Nope'))).style;
      expect(style.shadows, isNotEmpty);
      expect(tester.getSemantics(find.byType(Win98Button)).flagsCollection.isEnabled, isNot(true));
    });

    testWidgets('default button gets an outline', (tester) async {
      await tester.pumpHarness(
        Win98Button(isDefault: true, onPressed: () {}, child: const Text('OK')),
      );
      expect(
        find.byWidgetPredicate((w) => w is Bevel && w.style == BevelStyle.outline),
        findsOneWidget,
      );
    });

    testWidgets('activates from the keyboard when focused', (tester) async {
      var taps = 0;
      await tester.pumpHarness(
        Win98Button(autofocus: true, onPressed: () => taps++, child: const Text('OK')),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 1);
    });
  });

  group('Win98Window', () {
    testWidgets('renders title, body, and only the requested caption buttons', (tester) async {
      var closed = 0;
      await tester.pumpHarness(
        Win98Window(
          title: 'My Window',
          onClose: () => closed++,
          statusBar: const Win98StatusBar(panes: [Win98StatusPane(Text('Ready'))]),
          child: const Text('Body'),
        ),
      );
      expect(find.text('My Window'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.bySemanticsLabel('Minimize'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Close'));
      expect(closed, 1);
    });
  });

  group('Win98Checkbox', () {
    testWidgets('toggles via box and label', (tester) async {
      var value = false;
      await tester.pumpHarness(
        StatefulBuilder(
          builder: (context, setState) => Win98Checkbox(
            value: value,
            label: 'Enable',
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      await tester.tap(find.text('Enable'));
      await tester.pump();
      expect(value, isTrue);
      expect(find.byType(PixelGlyph), findsOneWidget);
      await tester.tap(find.text('Enable'));
      await tester.pump();
      expect(value, isFalse);
      expect(find.byType(PixelGlyph), findsNothing);
    });

    testWidgets('disabled checkbox does nothing', (tester) async {
      await tester.pumpHarness(const Win98Checkbox(value: false, label: 'Off', onChanged: null));
      await tester.tap(find.text('Off'));
      await tester.pump();
    });
  });

  group('Win98Radio', () {
    testWidgets('selects its value', (tester) async {
      String? group = 'a';
      await tester.pumpHarness(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              for (final v in ['a', 'b'])
                Win98Radio<String>(
                  value: v,
                  groupValue: group,
                  label: v.toUpperCase(),
                  onChanged: (x) => setState(() => group = x),
                ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(group, 'b');
      expect(
        tester.widget<Win98Radio<String>>(find.byType(Win98Radio<String>).last).selected,
        isTrue,
      );
    });
  });

  group('Win98Slider', () {
    Future<List<double>> pumpSlider(
      WidgetTester tester, {
      int? divisions,
      bool enabled = true,
    }) async {
      final changes = <double>[];
      var value = 0.0;
      await tester.pumpHarness(
        StatefulBuilder(
          builder: (context, setState) => Win98Slider(
            value: value,
            max: 10,
            divisions: divisions,
            onChanged: enabled ? (v) => setState(() => changes.add(value = v)) : null,
          ),
        ),
      );
      return changes;
    }

    testWidgets('tap jumps to the tapped position', (tester) async {
      final changes = await pumpSlider(tester, divisions: 10);
      final rect = tester.getRect(find.byType(Win98Slider));
      await tester.tapAt(Offset(rect.right - 7, rect.center.dy));
      expect(changes.last, 10);
      await tester.tapAt(Offset(rect.center.dx, rect.center.dy));
      expect(changes.last, 5);
    });

    testWidgets('drag moves the value and snaps to divisions', (tester) async {
      final changes = await pumpSlider(tester, divisions: 4);
      final rect = tester.getRect(find.byType(Win98Slider));
      await tester.dragFrom(Offset(rect.left + 7, rect.center.dy), Offset(rect.width * 0.8, 0));
      expect(changes, isNotEmpty);
      for (final v in changes) {
        expect(v % 2.5, 0);
      }
      expect(changes.last, greaterThanOrEqualTo(7.5));
    });

    testWidgets('arrow keys nudge the value', (tester) async {
      final changes = await pumpSlider(tester, divisions: 10);
      await tester.tap(find.byType(Win98Slider));
      changes.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(changes, isNotEmpty);
    });

    testWidgets('disabled slider ignores input', (tester) async {
      final changes = await pumpSlider(tester, enabled: false);
      await tester.tap(find.byType(Win98Slider));
      expect(changes, isEmpty);
    });
  });

  group('Win98Dropdown', () {
    testWidgets('opens a list and selects an item', (tester) async {
      var value = 'cga';
      await tester.pumpHarness(
        StatefulBuilder(
          builder: (context, setState) => Win98Dropdown<String>(
            value: value,
            items: const [
              Win98DropdownItem(value: 'cga', label: 'CGA'),
              Win98DropdownItem(value: 'ega', label: 'EGA'),
            ],
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      expect(find.text('CGA'), findsOneWidget);
      expect(find.text('EGA'), findsNothing);
      await tester.tap(find.text('CGA'));
      await tester.pump();
      expect(find.text('EGA'), findsOneWidget);
      await tester.tap(find.text('EGA'));
      await tester.pump();
      expect(value, 'ega');
      expect(find.text('CGA'), findsNothing); // popup closed
    });

    testWidgets('tapping outside closes without changing', (tester) async {
      var changed = false;
      await tester.pumpHarness(
        Win98Dropdown<int>(
          value: 1,
          items: const [
            Win98DropdownItem(value: 1, label: 'One'),
            Win98DropdownItem(value: 2, label: 'Two'),
          ],
          onChanged: (_) => changed = true,
        ),
      );
      await tester.tap(find.text('One'));
      await tester.pump();
      expect(find.text('Two'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.text('Two'), findsNothing);
      expect(changed, isFalse);
    });

    testWidgets('Next/Previous step through the options, wrapping at the ends', (tester) async {
      var value = 'a';
      await tester.pumpHarness(
        StatefulBuilder(
          builder: (context, setState) => Win98Dropdown<String>(
            value: value,
            items: const [
              Win98DropdownItem(value: 'a', label: 'A'),
              Win98DropdownItem(value: 'b', label: 'B'),
              Win98DropdownItem(value: 'c', label: 'C'),
            ],
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Next option'));
      await tester.pump();
      expect(value, 'b');
      await tester.tap(find.bySemanticsLabel('Next option'));
      await tester.pump();
      expect(value, 'c');
      await tester.tap(find.bySemanticsLabel('Next option'));
      await tester.pump();
      expect(value, 'a', reason: 'wraps past the last item');
      await tester.tap(find.bySemanticsLabel('Previous option'));
      await tester.pump();
      expect(value, 'c', reason: 'wraps before the first item');
    });

    testWidgets('Next/Previous are disabled with one item, or when disabled', (tester) async {
      await tester.pumpHarness(
        const Win98Dropdown<int>(
          value: 1,
          items: [Win98DropdownItem(value: 1, label: 'Only')],
          onChanged: null,
        ),
      );
      final next = tester.widget<Win98Button>(
        find.ancestor(of: find.bySemanticsLabel('Next option'), matching: find.byType(Win98Button)),
      );
      expect(next.enabled, isFalse);
    });
  });

  testWidgets('a drop-down near the bottom opens upward and stays on screen', (tester) async {
    await tester.pumpWidget(
      harness(
        Align(
          alignment: Alignment.bottomCenter,
          child: Win98Dropdown<int>(
            value: 0,
            items: [for (var i = 0; i < 12; i++) Win98DropdownItem(value: i, label: 'Item $i')],
            onChanged: (_) {},
          ),
        ),
        size: const Size(300, 600),
      ),
    );
    await tester.tap(find.text('Item 0'));
    await tester.pump();
    final field = tester.getRect(find.byType(Win98Dropdown<int>));
    // The list's first row is above the field and on screen.
    final first = tester.getRect(find.text('Item 0').last);
    expect(first.bottom, lessThanOrEqualTo(field.top));
    expect(first.top, greaterThanOrEqualTo(0));
  });

  group('Win98MenuBar', () {
    testWidgets('opens a menu and runs the selected item', (tester) async {
      var opened = 0;
      await tester.pumpHarness(
        Win98MenuBar(
          menus: [
            Win98Menu(
              label: 'File',
              items: [
                Win98MenuItem(label: 'Open...', onSelected: () => opened++, shortcut: 'Ctrl+O'),
                const Win98MenuDivider(),
                const Win98MenuItem(label: 'Disabled'),
              ],
            ),
          ],
        ),
      );
      await tester.tap(find.text('File'));
      await tester.pump();
      expect(find.text('Ctrl+O'), findsOneWidget);
      await tester.tap(find.text('Disabled'));
      await tester.pump();
      expect(find.text('Open...'), findsOneWidget); // disabled item keeps it open
      await tester.tap(find.text('Open...'));
      await tester.pump();
      expect(opened, 1);
      expect(find.text('Open...'), findsNothing);
    });

    testWidgets('without maxHeight, a long menu sizes to fit every item', (tester) async {
      await tester.pumpHarness(
        Win98MenuBar(
          menus: [
            Win98Menu(
              label: 'Presets',
              items: [for (var i = 0; i < 30; i++) Win98MenuItem(label: 'Preset $i')],
            ),
          ],
        ),
        size: const Size(360, 600),
      );
      await tester.tap(find.text('Presets'));
      await tester.pump();
      expect(find.text('Preset 0'), findsOneWidget);
      expect(find.text('Preset 29'), findsOneWidget);
      expect(find.byType(Win98Scrollbar), findsNothing);
    });

    testWidgets('with maxHeight, a long menu is capped and scrollable', (tester) async {
      await tester.pumpHarness(
        Win98MenuBar(
          menus: [
            Win98Menu(
              label: 'Presets',
              maxHeight: 120,
              items: [for (var i = 0; i < 30; i++) Win98MenuItem(label: 'Preset $i')],
            ),
          ],
        ),
        size: const Size(360, 600),
      );
      await tester.tap(find.text('Presets'));
      await tester.pump();
      // The panel doesn't grow past maxHeight (plus its own bevel chrome,
      // a few pixels of border/padding around the capped content)...
      final panel = tester.getRect(find.byType(Win98MenuPanel));
      expect(panel.height, lessThanOrEqualTo(140));
      // ...so the scrollable content lays out past the visible panel (it's
      // there, just off-screen until scrolled to), reachable via a
      // scrollbar.
      expect(find.text('Preset 0'), findsOneWidget);
      expect(tester.getRect(find.text('Preset 29')).top, greaterThan(panel.bottom));
      expect(find.byType(Win98Scrollbar), findsOneWidget);
    });
  });

  group('Win98TabView', () {
    testWidgets('switches pages', (tester) async {
      final changes = <int>[];
      await tester.pumpHarness(
        Win98TabView(
          onChanged: changes.add,
          tabs: [
            Win98Tab(label: 'One', builder: (_) => const Text('Page 1')),
            Win98Tab(label: 'Two', builder: (_) => const Text('Page 2')),
          ],
        ),
        size: const Size(360, 200),
      );
      expect(find.text('Page 1'), findsOneWidget);
      await tester.tap(find.text('Two'));
      await tester.pump();
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Page 1'), findsNothing);
      expect(changes, [1]);
    });
  });

  group('Win98TabView multi-row', () {
    List<Win98Tab> tabs() => [
      for (final name in ['Palette', 'Dither', 'Grid', 'Adjust', 'Effects', 'Presets'])
        Win98Tab(label: name, builder: (_) => Text('$name page')),
    ];

    testWidgets('wraps into rows that all fit on screen', (tester) async {
      await tester.pumpHarness(Win98TabView(tabs: tabs()), size: const Size(220, 300));
      final panel = tester.getRect(find.byType(Win98TabView));
      for (final name in ['Palette', 'Presets']) {
        final r = tester.getRect(find.text(name));
        expect(r.left, greaterThanOrEqualTo(panel.left));
        expect(r.right, lessThanOrEqualTo(panel.right));
      }
      expect(
        tester.getRect(find.text('Palette')).top,
        isNot(tester.getRect(find.text('Presets')).top),
      );
    });

    testWidgets('the selected row moves next to the panel', (tester) async {
      await tester.pumpHarness(Win98TabView(tabs: tabs()), size: const Size(220, 300));
      final paletteTopBefore = tester.getRect(find.text('Palette')).top;
      final presetsTopBefore = tester.getRect(find.text('Presets')).top;
      expect(paletteTopBefore, greaterThan(presetsTopBefore), reason: 'selected row is lowest');
      await tester.tap(find.text('Presets'));
      await tester.pump();
      expect(find.text('Presets page'), findsOneWidget);
      expect(
        tester.getRect(find.text('Presets')).top,
        greaterThan(tester.getRect(find.text('Palette')).top),
      );
    });
  });

  group('Win98ListBox', () {
    testWidgets('selects and activates rows', (tester) async {
      String? selected;
      String? activated;
      await tester.pumpHarness(
        StatefulBuilder(
          builder: (context, setState) => Win98ListBox<String>(
            items: const [
              Win98ListItem(value: 'a', label: 'Alpha'),
              Win98ListItem(value: 'b', label: 'Beta'),
            ],
            selected: selected,
            onSelected: (v) => setState(() => selected = v),
            onActivated: (v) => activated = v,
          ),
        ),
      );
      await tester.tap(find.text('Beta'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(selected, 'b');
      await tester.tap(find.text('Alpha'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Alpha'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(activated, 'a');
    });
  });

  group('Win98ScrollView', () {
    testWidgets('shows a scrollbar only when content overflows', (tester) async {
      await tester.pumpHarness(
        const Win98ScrollView(child: SizedBox(height: 50)),
        size: const Size(200, 200),
      );
      expect(find.bySemanticsLabel('Scroll down'), findsNothing);

      await tester.pumpHarness(
        const Win98ScrollView(child: SizedBox(height: 1000)),
        size: const Size(200, 200),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Scroll down'), findsOneWidget);
    });

    testWidgets('arrow buttons scroll the content', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpHarness(
        Win98ScrollView(controller: controller, child: const SizedBox(height: 1000)),
        size: const Size(200, 200),
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Scroll down'));
      await tester.pump();
      expect(controller.offset, 40);
      await tester.tap(find.bySemanticsLabel('Scroll up'));
      await tester.pump();
      expect(controller.offset, 0);
    });
  });

  group('Win98TextField', () {
    testWidgets('accepts typing and submit', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? submitted;
      await tester.pumpHarness(
        Win98TextField(controller: controller, onSubmitted: (v) => submitted = v),
      );
      await tester.tap(find.byType(Win98TextField));
      await tester.enterText(find.byType(EditableText), 'hello');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(controller.text, 'hello');
      expect(submitted, 'hello');
    });
  });

  group('Win98ProgressBar', () {
    testWidgets('determinate and indeterminate render', (tester) async {
      await tester.pumpHarness(const Win98ProgressBar(value: 0.5));
      expect(tester.getSemantics(find.byType(Win98ProgressBar)).value, '50%');
      await tester.pumpHarness(const Win98ProgressBar());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpHarness(const SizedBox()); // disposes the ticker
    });
  });

  group('Win98StatusBar', () {
    testWidgets('content-sized panes are capped instead of overflowing', (tester) async {
      await tester.pumpHarness(
        const Win98StatusBar(
          panes: [
            Win98StatusPane(Text('Ready')),
            Win98StatusPane(Text('a very very long statistics pane'), flex: 0),
            Win98StatusPane(Text('another long statistics pane'), flex: 0),
          ],
        ),
        size: const Size(240, 40),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.text('Ready')).width, greaterThan(0));
    });
  });

  group('Win98GroupBox', () {
    testWidgets('shows caption and child', (tester) async {
      await tester.pumpHarness(const Win98GroupBox(label: 'Options', child: Text('Inside')));
      expect(find.text('Options'), findsOneWidget);
      expect(find.text('Inside'), findsOneWidget);
    });
  });

  group('dialogs', () {
    testWidgets('message box returns the pressed button index', (tester) async {
      Future<int?>? result;
      await tester.pumpHarness(
        Builder(
          builder: (context) => Win98Button(
            onPressed: () => result = showWin98MessageBox(
              context: context,
              title: 'Confirm',
              message: 'Delete it?',
              icon: Win98MessageIconType.question,
              buttons: const ['Yes', 'No'],
            ),
            child: const Text('Ask'),
          ),
        ),
      );
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      expect(find.text('Delete it?'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(await result, 1);
      expect(find.text('Delete it?'), findsNothing);
    });

    testWidgets('closing from the title bar returns null', (tester) async {
      Future<int?>? result;
      await tester.pumpHarness(
        Builder(
          builder: (context) => Win98Button(
            onPressed: () =>
                result = showWin98MessageBox(context: context, title: 'Info', message: 'Hi'),
            child: const Text('Show'),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });

    testWidgets('color dialog returns the picked color', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      Future<Color?>? result;
      await tester.pumpHarness(
        Builder(
          builder: (context) => Win98Button(
            onPressed: () =>
                result = showWin98ColorDialog(context: context, initial: const Color(0xFF000000)),
            child: const Text('Pick'),
          ),
        ),
      );
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('#FF0000'));
      await tester.pump();
      expect(find.text('#FF0000'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(await result, const Color(0xFFFF0000));
    });

    testWidgets('color dialog cancel returns null', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      Future<Color?>? result;
      await tester.pumpHarness(
        Builder(
          builder: (context) => Win98Button(
            onPressed: () =>
                result = showWin98ColorDialog(context: context, initial: const Color(0xFF00FF00)),
            child: const Text('Pick'),
          ),
        ),
      );
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(find.text('#00FF00'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });
  });
}
