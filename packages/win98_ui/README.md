# win98_ui

A Windows 98 look-and-feel widget kit for Flutter. Depends only on
`package:flutter/widgets.dart` — no Material or Cupertino — so it drops into
any app.

Built for [Bitmapper](../../README.md), kept self-contained so it can be
reused as-is (path/git dependency) or published.

## Setup

```yaml
dependencies:
  win98_ui:
    path: packages/win98_ui   # or a git dependency
```

Wrap your app in a `Win98Theme` *above* the navigator so dialogs inherit it:

```dart
WidgetsApp(
  color: const Color(0xFF008080),
  builder: (context, navigator) => Win98Theme(child: navigator!),
  pageRouteBuilder: <T>(settings, builder) =>
      PageRouteBuilder<T>(settings: settings, pageBuilder: (c, _, _) => builder(c)),
  home: const MyHome(),
);
```

`MaterialApp.builder` works the same way.

## Widgets

| Widget | Notes |
|---|---|
| `Win98Theme` / `Win98ThemeData` | Colors (face, highlight, shadow, selection, title gradient, desktop), font, control metrics |
| `Bevel`, `BevelPainter` | The 2-px borders everything is built from: raised, window, pressed, field, status, etched, outline |
| `Win98Button` | Pressed state, default-button outline, focus rectangle, etched disabled text, keyboard activation |
| `Win98Window`, `Win98TitleBar`, `Win98Desktop` | Title bar with gradient and caption buttons, optional menu and status bars; `expand` pins the status bar to the bottom |
| `Win98MenuBar`, `Win98Menu`, `Win98MenuItem`, `Win98MenuDivider`, `Win98MenuPanel` | Drop-down menus in an `OverlayPortal`, with shortcut hints, checkmarks and disabled items; `maxHeight` caps and scrolls a long menu instead of letting it overflow |
| `Win98TabView`, `Win98Tab` | Property-sheet tabs; scrolls sideways when the tabs don't fit |
| `Win98GroupBox` | Etched frame with a caption |
| `Win98Checkbox`, `Win98Radio<T>` | With labels, focus and semantics |
| `Win98Slider` | Trackbar with ticks; drag, tap-to-jump, arrow keys |
| `Win98Dropdown<T>` | Combo box with a pop-up list, plus Previous/Next buttons to step through options without opening it |
| `Win98TextField` | `EditableText` in a sunken field |
| `Win98ListBox<T>` | Selection highlight, double-tap to activate |
| `Win98ScrollView`, `Win98Scrollbar` | Arrow buttons, dithered track, draggable thumb |
| `Win98ProgressBar` | Blocky segments, or an indeterminate marquee |
| `Win98StatusBar` | Sunken panes |
| `showWin98Dialog`, `showWin98MessageBox`, `Win98MessageIcon` | Modal windows; message boxes with info/warning/error/question icons |
| `showWin98ColorDialog`, `Win98ColorPicker` | Paint-style "Edit Colors" with the 48 basic colors and R/G/B sliders |
| `PixelGlyph`, `Win98Glyphs` | 1-bit bitmap glyphs (arrows, check, caption symbols) |
| `Win98PopupAnchor` | The overlay anchoring used by menus and drop-downs |

Sizes are slightly larger than 1998's so controls stay usable touch targets.

## Font

Ships [Pixelify Sans](https://github.com/eifetx/Pixelify-Sans) under the SIL
Open Font License (`fonts/OFL.txt`). Override `Win98ThemeData.fontFamily`
(and `fontPackage: null`) to use your own.

## Tests

```sh
flutter test                              # widget + golden tests
flutter test --tags golden --update-goldens   # regenerate goldens (macOS)
```

The gallery is in `example/` (run `flutter create .` there to add platform
folders).
