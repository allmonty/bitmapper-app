# GPU / overall performance research spike

## Status: research only, not started

This doc exists so a future session (or another AI) can pick this up without
re-deriving the background. It records what's true about the app's
performance architecture today, and what a GPU-offload spike would actually
involve — it is **not** an implementation plan, because whether it's worth
doing depends on results from a smaller, already-scoped fix that should ship
first (see "Do this before starting a GPU spike" below).

## Where this came from

The user asked: "I want to try to improve the performance as a whole. Is it
possible to use GPU? Are we already using? How could we make the app
faster?" — alongside a specific complaint that the app feels slow while
navigating tabs on a weaker Android phone. That specific complaint has
already been investigated and addressed (see below); this doc is about the
open-ended "can the pipeline itself go faster" question.

## Current state: pure CPU, isolate-based

The whole filter pipeline (`packages/bitmapper_core/lib/src/pipeline.dart`
and every stage file it calls: adjustments, downsample, `toon.dart`
(shade bands, despeckle), palette generation/quantization, `dither.dart`,
`outline.dart`, `grid.dart` (upscale/gaps), scanlines) is plain Dart running
on the CPU. It's dispatched to a background isolate
(`lib/services/filter_controller.dart`) so the UI thread never blocks, but
"background isolate" still means CPU, not GPU — Dart isolates don't get
you GPU compute.

Confirmed by grep: nothing in `lib/`, `packages/bitmapper_core/lib/`, or
`packages/win98_ui/lib/` references `dart:ui`'s `FragmentProgram` or
`FragmentShader` (the two APIs Flutter exposes for writing custom GPU
shaders). The only `dart:ui` usage in the app is ordinary image
encode/decode (`lib/services/image_codec.dart`, `lib/widgets/rgb_image_view.dart`),
unrelated to compute. There is no GPU usage anywhere in this codebase today.

## Do this before starting a GPU spike

The reported "slow while navigating tabs" symptom was investigated
separately and turned out to have two concrete, already-fixed causes —
neither of which was actually a GPU/compute problem:

1. Live preview used `Isolate.run` (spawns a fresh isolate — with its
   startup cost and typed-data copy — on every debounced preview request)
   instead of a reused worker isolate. Fixed: `PreviewIsolate` in
   `lib/services/filter_controller.dart` now spawns one isolate and reuses
   it for the app's lifetime.
2. `Win98TabView` (`packages/win98_ui/lib/src/tabs.dart`) re-ran text
   layout for every tab label on **every rebuild** (not just when the tab
   selection or available width changed), because the layout call sat
   inside a `LayoutBuilder` callback that reruns on every build. Fixed:
   `TabLabelWidthCache` memoizes it.

Both were real, verified, synchronous-on-the-UI-thread costs paid
constantly during normal interaction (slider drags, tab switches — anything
that rebuilds `HomeScreen`). Since these are the most likely dominant costs
on a weaker phone, **re-measure on the reporting user's actual device after
these two fixes ship**, before spending time on a GPU rewrite. If it's still
slow after that, the next suspect is the filter pipeline's own CPU cost,
which is where a GPU spike would come in.

## If a GPU spike is still warranted

Flutter's relevant API is `dart:ui`'s `FragmentProgram`/`FragmentShader`:
you write a GLSL-like shader (`.frag` file, compiled via `flutter_shaders`
or raw `FragmentProgram.fromAsset`), bind it as a `Paint.shader`, and it
runs on the GPU when the `CustomPainter` draws.

**This only works cleanly for stages that are "embarrassingly parallel"** —
each output pixel computed independently of its neighbours, with no
state carried between pixels:
- Adjustments (brightness/contrast/saturation/etc.) — pure per-pixel math,
  ideal for a shader.
- Palette nearest-color mapping — per-pixel, but needs the palette as a
  lookup table (a small texture uniform); straightforward.
- Scanlines — a pure per-pixel overlay, ideal.

**These stages have sequential/neighbour dependencies and do NOT translate
directly to a single shader pass:**
- Error-diffusion dither (`dither.dart`'s Floyd–Steinberg/Atkinson/etc.) —
  each pixel's quantization error is propagated to not-yet-processed
  neighbours; this is inherently serial within a scanline (and often across
  rows). Possible on GPU only via a multi-pass or wavefront algorithm,
  which is a substantial rewrite, not a shader port.
- Despeckle (`toon.dart`) — reads each cell's neighbourhood and picks a
  majority color; parallel per output pixel *if* done as a single read-only
  pass over the pre-despeckle grid (this one's actually not bad — no
  cross-pixel write ordering issue, just a wider per-pixel neighbourhood
  read), but still needs care around the grid's edges (matches CPU version's
  boundary handling, see `toon.dart`'s existing tie-break logic).
- Outline mask growth/closing (`outline.dart`'s `thickness` dilation and
  `closeGaps` binary closing) — genuinely sequential (each dilation/erosion
  step depends on the previous step's full output), needs one shader pass
  per iteration (thickness is capped at 3, closing is 2 steps, so this is
  *bounded* and could work as a small fixed number of ping-ponged passes,
  but it's still meaningfully more complex than the stateless stages).

## Recommendation

1. Ship the isolate-reuse and tab-label-cache fixes (already done — see
   git log) and get feedback from the user's friend on the actual device.
2. If still slow, profile which specific pipeline stage(s) dominate at
   realistic grid sizes (add a `Stopwatch` per stage temporarily, or use
   Flutter DevTools' CPU profiler on a real device) before assuming it's
   "the whole pipeline" — there may be one hot stage (e.g. palette
   generation via median-cut, which is O(n log n) over all sampled pixels)
   that's worth optimizing in plain Dart first, which is far cheaper than a
   GPU rewrite.
3. If a GPU spike is still justified, scope it to the stateless stages only
   (adjustments, palette nearest-color, scanlines) as a self-contained
   first cut — those compose into a single shader pass and give the
   biggest win for the least risk. Leave dither/despeckle/outline on the
   CPU path; they're comparatively cheap per-pixel anyway (bounded
   neighbourhood reads or already-optimized loops) compared to the
   full-image passes.
4. Any GPU path needs a CPU fallback — some Android devices/emulators have
   patchy `FragmentProgram` support, and `bitmapper_core` must stay
   Flutter-free per `CLAUDE.md` (it's pure Dart, testable without a
   `dart:ui` binding), so a GPU path would have to live in the app layer
   (`lib/`), not the engine package, with the CPU pipeline remaining the
   source of truth for byte-exact goldens.
