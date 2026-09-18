import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:win98_ui/win98_ui.dart';

/// A minimal WidgetsApp (navigator + overlay) with the Win98 theme.
Widget harness(Widget child, {Size? size}) {
  return WidgetsApp(
    color: const Color(0xFF008080),
    debugShowCheckedModeBanner: false,
    builder: (context, navigator) => Win98Theme(child: navigator!),
    pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
        PageRouteBuilder<T>(settings: settings, pageBuilder: (c, _, _) => builder(c)),
    home: Win98Desktop(
      child: Center(
        child: SizedBox(width: size?.width ?? 360, height: size?.height, child: child),
      ),
    ),
  );
}

/// Loads the bundled pixel font so goldens show real glyphs instead of the
/// test font's boxes.
Future<void> loadWin98Font() async {
  final bytes = File('fonts/PixelifySans.ttf').readAsBytesSync();
  final loader = FontLoader('packages/win98_ui/PixelifySans')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

extension PumpHarness on WidgetTester {
  Future<void> pumpHarness(Widget child, {Size? size}) async {
    await pumpWidget(harness(child, size: size));
    await pump();
  }
}
