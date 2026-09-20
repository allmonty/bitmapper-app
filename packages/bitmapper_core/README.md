# bitmapper_core

Pure-Dart retro pixel-art filter engine: adjustments → downsample to a grid
→ shade bands (toon) → palette (fixed / custom / median cut / k-means) →
dither (19 methods) → despeckle → outline (ink on edges, several methods) →
upscale with optional gutters → scanlines. It has no Flutter dependency, so
it runs in `Isolate.run` and tests with `dart test`.

```dart
final result = applyBitmapFilter(
  RgbImage.fromRgba(w, h, rgba),
  getPreset('gameboy_camera').copyWith(gridCols: 120, gridRows: 90),
  outputWidth: w,
  outputHeight: h,
);
```

## Numeric design notes

A few deliberate choices worth knowing before touching the math:

- **No canvas resize.** The source is downsampled straight to the grid, and
  the output size only affects the final upscale.
- **Deterministic k-means init.** Evenly spaced entries of the sorted unique
  colors, rather than random sampling, so a run is reproducible.
- **`random` dither uses xorshift128+.** It's seeded from `config.randomSeed`,
  so a given seed always gives the same output.
- **Median cut sorts stably**, so ties on the split channel resolve the same
  way every run.
- **Blocks are spread evenly.** When the size doesn't divide evenly, grid
  blocks differ by at most one pixel and the extra pixels are spread across
  the image (`splitSizes`), rather than all front-loaded onto the first
  blocks — front-loading squeezes the start of the image and stretches the
  rest, a visible distortion that changes with the column count.
- **API shape.** `outputWidth`/`outputHeight` are arguments to
  `applyBitmapFilter` rather than config fields, and colors are packed
  `0xRRGGBB` ints.

Everything else is bit-exact by design: uint8 truncation, a fixed float
operation order, and round-half-even in `subsample`. Several tests assert
exact byte arrays for fixed inputs as a regression guard on that — if one
fails, a stage's numeric behavior changed; treat that as a deliberate,
reviewed decision and update the expected array in the same change.

## Toon shading and outlines

`toon.dart` runs on the quantized grid, after palette/dither and before
outline:

- `applyShadeBands(grid, bands)`: `bands` 0 is off, else 2-8 flat brightness
  bands, flattening luma toward each band's mid-point brightness.
- `despeckle(grid)`: replaces a cell whose color matches none of its 8
  neighbours with the most common neighbour color (reads the original grid,
  so scan order doesn't matter; ties go to the first-seen neighbour).

`outline.dart` inks edges on the quantized grid with a fixed palette color,
choosing edges and ink the way `dither.dart` chooses a dither method — via a
string parameter checked against a `List` of registered names:

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
- `luminance(r, g, b)`: Rec. 601 luma, computed as
  `(r*0.299 + g*0.587) + b*0.114` in that exact order.

## Palettes

`lib/src/palettes_data.dart` is generated from `tool/palette_source.py`; do
not edit it by hand. Regenerate it (from the repo root, with `numpy`
installed — `pip install -r tool/requirements.txt`) with:

```sh
python3 tool/gen_palettes.py
```

## Benchmark

```sh
dart compile exe tool/benchmark.dart -o /tmp/bench && /tmp/bench
```

On a 1200×1200 source with a 150×150 grid, the full pipeline takes about
25 ms (AOT, Apple Silicon).

Large palettes stay fast because of two optimizations. Tests check that
both give exactly the same output as the straightforward versions:

- `PaletteSearch`: nearest-color lookups over entries sorted by red, with
  early exit, using the same distance and lowest-index tie rule as
  `nearestIndex`.
- Median cut keeps its bucket list sorted incrementally instead of
  re-sorting it on every split.

With these, a 12-bit (4096-color) auto palette on a 120-column grid takes
about 130 ms, where it used to take 13 s.

`tool/benchmark_stages.dart` times every pipeline stage separately instead
of the whole pipeline as one call, on two scenarios mirroring the app's
real preview and export requests:

```sh
dart compile exe tool/benchmark_stages.dart -o /tmp/bench_stages && /tmp/bench_stages
```

Use this before assuming "the pipeline" is slow — there's usually one hot
stage, not a uniformly slow whole. See `docs/plans/gpu-performance.md` (repo
root) for a worked example: it found `applyScanlines` was the single most
expensive export stage, due to a per-byte `clampToByte` call with no lookup
table, not anything resolution-inherent.
