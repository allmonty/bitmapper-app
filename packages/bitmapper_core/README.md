# bitmapper_core

Pure-Dart port of the Python `bitmapper` reference (`../../../bitmapper`):
adjustments → downsample to a grid → shade bands (toon) → palette (fixed /
custom / median cut / k-means) → dither (19 methods) → despeckle → outline
(ink on edges, several methods) → upscale with optional gutters → scanlines.
It has no Flutter dependency, so it runs in `Isolate.run` and tests with
`dart test`.

```dart
final result = applyBitmapFilter(
  RgbImage.fromRgba(w, h, rgba),
  getPreset('gameboy_camera').copyWith(gridCols: 120, gridRows: 90),
  outputWidth: w,
  outputHeight: h,
);
```

## Differences from the Python reference

These follow `docs/FLUTTER_MIGRATION.md`:

- **No canvas resize.** The source is downsampled straight to the grid, and
  the output size only affects the final upscale (§6.1).
- **Deterministic k-means init.** Evenly spaced entries of the sorted unique
  colors instead of PCG64 sampling (§6.4b).
- **`random` dither uses xorshift128+.** It's seeded from `config.randomSeed`,
  so a given seed always gives the same output (§6.4a).
- **Median cut sorts stably.** NumPy's default argsort isn't stable, so ties
  on the split channel can differ from Python.
- **Blocks are spread evenly.** When the size doesn't divide evenly, grid
  blocks differ by at most one pixel and the extra pixels are spread across
  the image (`splitSizes`). `np.array_split` gives all the extra pixels to
  the first blocks. That squeezes the start of the image and stretches the
  rest, a visible distortion that changes with the column count. Python hid
  it by resizing to a canvas that the default grid divides exactly; without
  that resize (above), it showed.
- **API shape.** `output_size` is an argument rather than a config field, and
  colors are packed `0xRRGGBB` ints.

Everything else is intended to be bit-exact: uint8 truncation, float
operation order, and round-half-even in `subsample`.
The tests compare stage outputs byte for byte against values produced by the
Python code.

## Toon shading and outlines

`toon.dart` (ported from Python's `toon.py`) runs on the quantized grid,
after palette/dither and before outline:

- `applyShadeBands(grid, bands)`: `bands` 0 is off, else 2-8 flat brightness
  bands, flattening luma toward each band's mid-point brightness.
- `despeckle(grid)`: replaces a cell whose color matches none of its 8
  neighbours with the most common neighbour color (reads the original grid,
  so scan order doesn't matter; ties go to the first-seen neighbour).

`outline.dart` (ported from `outline.py`) inks edges on the quantized grid
with a fixed palette color, choosing edges and ink the way `dither.dart`
chooses a dither method — via a string parameter checked against a `List`
of registered names:

- `applyOutline(grid, palette, strength, method, ink)`. `strength` (0-1)
  sets `outlineThreshold`; `kOutlineMethods` are `brightness` (4-neighbour
  luma comparison — the original, but noisy on photo texture), `color` (RGB
  distance, also catches same-luma hue edges) and `sobel` (a 3x3 gradient
  that also finds diagonal/gradual edges and closes gaps the others leave
  broken — the best default for photos). `kOutlineInks` are `darkest` (the
  palette's darkest entry) and `shaded` (the palette color nearest a
  half-brightness copy of the outlined pixel, falling back to `darkest`
  when that's the same color).

## Shared color helpers

`color.dart` is the one place color packing and luminance are implemented —
every stage that needs them (`outline.dart`, `toon.dart`, `adjustments.dart`,
`palette_gen.dart`, `pipeline.dart`), and the app's preview painter, GIF
export and palette tab, import it rather than re-implementing:

- `packRgb`/`packedAt`/`unpackRgb`: pack/unpack a color as `0xRRGGBB`.
- `packedColors`/`colorSet`: every pixel of a flat RGB(A) buffer as packed
  colors, in order or deduplicated (`stride: 4` skips the alpha byte).
- `paletteFromPacked`: packed colors back to a flat RGB `Uint8List` palette.
- `luminance(r, g, b)`: Rec. 601 luma as `(r*0.299 + g*0.587) + b*0.114`, in
  the same operation order as Python's `_luminance` so results match exactly.

## Palettes

`lib/src/palettes_data.dart` is generated from Python:

```sh
../bitmapper/.venv/bin/python tool/gen_palettes.py   # from the repo root
```

## Benchmark

```sh
dart compile exe tool/benchmark.dart -o /tmp/bench && /tmp/bench
```

On a 1200×1200 source with a 150×150 grid, the full pipeline takes about
25 ms (AOT, Apple Silicon). The Python reference takes about 240 ms.

Large palettes stay fast because of two optimizations. Tests check that
both give exactly the same output as the straightforward versions:

- `PaletteSearch`: nearest-color lookups over entries sorted by red, with
  early exit, using the same distance and lowest-index tie rule as
  `nearestIndex`.
- Median cut keeps its bucket list sorted incrementally instead of
  re-sorting it on every split.

With these, a 12-bit (4096-color) auto palette on a 120-column grid takes
about 130 ms, where it used to take 13 s.
