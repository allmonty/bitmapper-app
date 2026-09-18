# Bitmapper

A retro pixel-art photo filter for Android and iOS, with a Windows 98 UI.
It's a Flutter port of the Python [`bitmapper`](../bitmapper), plus the app
features from [ColorTrix](../colortrix): opening images, presets, saving,
hold-to-compare, and zoom.

## Layout

| Path | What |
|---|---|
| `lib/` | The app: Provider + `ChangeNotifier` models, services, Win98 screens |
| `packages/bitmapper_core/` | Filter engine, pure Dart ([README](packages/bitmapper_core/README.md)) |
| `packages/win98_ui/` | Reusable Windows 98 widget kit ([README](packages/win98_ui/README.md)) |
| `tool/gen_palettes.py` | Regenerates the palette table from the Python reference |

## Features

- **Open images** from the gallery or camera (`image_picker`). Images are
  capped at 4096 px on the long edge.
- **Live preview** on a background isolate. It is debounced and
  latest-wins, and renders from a copy capped at 1024 px.
- **Controls:**
  - Palette: auto (median cut or k-means), 14 fixed palettes, or a custom
    palette edited with a Win98 color dialog.
  - Bit depth: up to 12 bits (4096 colors) in auto mode, then true color;
    up to 8 bits for fixed and custom palettes.
  - 12 dither methods and dither strength.
  - Pixel columns from 16 to 512 (rows follow the aspect ratio), block sampling, and grid
    gap with gap color.
  - Contrast, saturation, gamma, and scanlines.
- **Presets:** the 8 built-in looks from the Python reference, plus user
  presets saved to `shared_preferences`.
- **Save as** renders at full resolution, encodes PNG in an isolate, and
  opens the system save dialog (`flutter_file_dialog`). It needs no
  permissions.
- **Animated GIFs:** open a GIF, scrub through its frames, and save it back
  as an animated GIF. Up to 1000 frames are loaded, capped at 640 px on the
  long edge.
  - **Palette across frames:** built from the first frame, from sampled
    frames, or from each frame. Each frame may flicker.
  - **Random noise:** static (the same on every frame) or animated.
  - **Size:** the original size, or N pixels per grid cell for crisp pixel
    art and small files.
  - **Animation-friendly settings** (sampled palette, ordered dither) are
    one button away and never applied automatically. The status bar warns
    when an error-diffusion dither may shimmer.
  - Export runs on a worker isolate, with progress and a Cancel button.
    Frames of up to 256 colors are written exactly; deeper palettes are
    reduced by the GIF encoder.
- **Hold to compare** the original, and **pinch to zoom**.
- **English and Portuguese**, following the device locale.

## Commands

```sh
flutter pub get
flutter run
flutter analyze
flutter test                                    # app tests
(cd packages/bitmapper_core && dart test)       # engine tests
(cd packages/win98_ui && flutter test)          # kit tests, including goldens
flutter gen-l10n                                # after editing lib/l10n/*.arb
```

## Release notes

- Android release builds still use the debug signing config from the
  template. Set up a keystore before publishing.
- The app icon is still the Flutter default.
