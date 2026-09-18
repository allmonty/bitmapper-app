import 'package:flutter/widgets.dart';

/// Colors, typography and metrics of the Windows 98 look.
///
/// Metrics are in logical pixels and a bit larger than the 1998 originals so
/// controls stay comfortable touch targets on phones; bevel lines stay one
/// logical pixel wide, which keeps the chunky look on high-DPI screens.
@immutable
class Win98ThemeData {
  const Win98ThemeData({
    this.face = const Color(0xFFC0C0C0),
    this.highlight = const Color(0xFFFFFFFF),
    this.light = const Color(0xFFDFDFDF),
    this.shadow = const Color(0xFF808080),
    this.darkShadow = const Color(0xFF000000),
    this.window = const Color(0xFFFFFFFF),
    this.text = const Color(0xFF000000),
    this.disabledText = const Color(0xFF808080),
    this.selection = const Color(0xFF000080),
    this.selectionText = const Color(0xFFFFFFFF),
    this.desktop = const Color(0xFF008080),
    this.activeTitleStart = const Color(0xFF000080),
    this.activeTitleEnd = const Color(0xFF1084D0),
    this.inactiveTitleStart = const Color(0xFF808080),
    this.inactiveTitleEnd = const Color(0xFFB5B5B5),
    this.titleText = const Color(0xFFFFFFFF),
    this.tooltip = const Color(0xFFFFFFE1),
    this.fontFamily = 'PixelifySans',
    this.fontPackage = 'win98_ui',
    this.fontSize = 15,
    this.controlHeight = 32,
    this.titleBarHeight = 28,
    this.scrollbarSize = 20,
  });

  final Color face;
  final Color highlight;
  final Color light;
  final Color shadow;
  final Color darkShadow;

  /// Background of text fields, list boxes and other "field" surfaces.
  final Color window;
  final Color text;
  final Color disabledText;
  final Color selection;
  final Color selectionText;
  final Color desktop;
  final Color activeTitleStart;
  final Color activeTitleEnd;
  final Color inactiveTitleStart;
  final Color inactiveTitleEnd;
  final Color titleText;
  final Color tooltip;

  /// Font family, and the package that bundles it (`null` for an app font).
  final String fontFamily;
  final String? fontPackage;
  final double fontSize;

  /// Minimum height of buttons, fields and list rows.
  final double controlHeight;
  final double titleBarHeight;
  final double scrollbarSize;

  TextStyle get textStyle => TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: fontSize,
    color: text,
    height: 1.2,
  );

  TextStyle get boldTextStyle => textStyle.copyWith(fontWeight: FontWeight.w700);

  /// Win98's "etched" disabled text: gray with a white drop shadow.
  TextStyle get disabledTextStyle => textStyle.copyWith(
    color: disabledText,
    shadows: [Shadow(color: highlight, offset: const Offset(1, 1))],
  );

  Win98ThemeData copyWith({
    Color? face,
    Color? desktop,
    Color? selection,
    Color? activeTitleStart,
    Color? activeTitleEnd,
    String? fontFamily,
    String? fontPackage,
    double? fontSize,
    double? controlHeight,
  }) {
    return Win98ThemeData(
      face: face ?? this.face,
      highlight: highlight,
      light: light,
      shadow: shadow,
      darkShadow: darkShadow,
      window: window,
      text: text,
      disabledText: disabledText,
      selection: selection ?? this.selection,
      selectionText: selectionText,
      desktop: desktop ?? this.desktop,
      activeTitleStart: activeTitleStart ?? this.activeTitleStart,
      activeTitleEnd: activeTitleEnd ?? this.activeTitleEnd,
      inactiveTitleStart: inactiveTitleStart,
      inactiveTitleEnd: inactiveTitleEnd,
      titleText: titleText,
      tooltip: tooltip,
      fontFamily: fontFamily ?? this.fontFamily,
      fontPackage: fontPackage ?? this.fontPackage,
      fontSize: fontSize ?? this.fontSize,
      controlHeight: controlHeight ?? this.controlHeight,
      titleBarHeight: titleBarHeight,
      scrollbarSize: scrollbarSize,
    );
  }
}

/// Provides [Win98ThemeData] to descendants and sets the default text style.
class Win98Theme extends StatelessWidget {
  const Win98Theme({super.key, this.data = const Win98ThemeData(), required this.child});

  final Win98ThemeData data;
  final Widget child;

  /// The nearest theme, or the default theme when there is none.
  static Win98ThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InheritedWin98Theme>()?.data ??
      const Win98ThemeData();

  @override
  Widget build(BuildContext context) {
    return _InheritedWin98Theme(
      data: data,
      child: DefaultTextStyle(style: data.textStyle, child: child),
    );
  }
}

class _InheritedWin98Theme extends InheritedWidget {
  const _InheritedWin98Theme({required this.data, required super.child});

  final Win98ThemeData data;

  @override
  bool updateShouldNotify(_InheritedWin98Theme oldWidget) => data != oldWidget.data;
}
