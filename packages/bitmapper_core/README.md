# bitmapper_core

Pure-Dart port of the Python `bitmapper` reference (`../../../bitmapper`):
downsample to a grid → palette (fixed / custom / median cut / k-means) →
dither (11 methods) → upscale with optional gutters → scanlines. It has no
Flutter dependency, so it runs in `Isolate.run` and tests with `dart test`.

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
