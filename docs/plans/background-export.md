# Background export with a progress notification

## Status: Phase 1 shipped. Phases 2/3 (real background survival) not
started — see below, they're the bulk of the remaining work.

## Where this came from

The user: "I would like to be able to start saving/process the video and
close the app. Maybe could a notification show with the loading/processing
state. It's because for long videos it's taking so long." Two asks bundled
together: (a) a progress notification during export, and (b) the export
surviving the app being backgrounded or closed. They're separable — (a) is
achievable now; (b) needs real native work and, on iOS, may not be fully
achievable at all.

## Current state (verified by reading the code, not assumed)

- `lib/services/video_exporter.dart`'s `exportVideoInIsolate` and
  `lib/services/animation_exporter.dart`'s `exportGifInIsolate` already
  spawn a `dart:isolate` worker (`Isolate.spawn`) and talk over
  `ReceivePort`/`SendPort`. So export work is already off the UI isolate —
  but a Dart isolate is a child of the app **process**. It dies the instant
  the process is killed (user swipes the app away, or iOS/Android reclaims
  it after backgrounding). There is no persistence layer today.
- Progress plumbing is entirely tied to a live widget:
  `lib/services/export_actions.dart`'s `_runExport` creates a
  `ValueNotifier<(int, int)?> progress` as a **local variable**, wires it as
  the `onProgress` callback, and shows a `Win98Dialog` bound to it via
  `ValueListenableBuilder`. The dialog's `.whenComplete(...)` calls
  `task.cancel()` — so if that dialog widget goes away (navigator pop, or
  the route being torn down), the export is **actively cancelled**, not
  just orphaned. `progress.dispose()` also runs in the `finally` block.
  Net effect: closing/backgrounding the app today doesn't just risk losing
  progress updates, it can outright cancel the export.
- `pubspec.yaml` has **no** background-execution or notification
  dependency: no `flutter_local_notifications`, `workmanager`,
  `flutter_foreground_task`, or similar. `grep -ri notification` across
  `lib/`, `pubspec.yaml`, `android/`, `ios/` returns zero hits — there is no
  existing precedent anywhere in this app for a notification, a foreground
  service, or a WorkManager task. This is a net-new capability, not an
  extension of something that already exists.

## Phase 1 — Android: a progress notification while foregrounded — DONE

Shipped: `flutter_local_notifications` (22.3.1) via `AppServices.exportNotifier`
(`lib/services/export_notifier.dart`), wired into `export_actions.dart`'s
`_runExport` at exactly the points the plan above called for (start,
throttled progress, succeed, fail, cancel). Tested via `FakeExportNotifier`
in `test/helpers.dart`.

Real-world things found while implementing, worth knowing if you touch this
again:
- **`flutter_local_notifications` requires core library desugaring.**
  `android/app/build.gradle.kts` needed
  `compileOptions.isCoreLibraryDesugaringEnabled = true` plus a
  `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }`
  block — the build fails with a clear `AAR metadata` error without it.
  Confirmed by an actual `flutter build apk --debug` failing, then
  succeeding after this fix.
- **No manifest edits were needed.** `POST_NOTIFICATIONS`, a `<service>`
  and a `<receiver>` all merge in automatically from the plugin's own
  manifest — confirmed by inspecting the actual merged manifest at
  `build/app/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml`
  after a build, not assumed.
- **`android.newDsl=false`** (already set in `android/gradle.properties`
  from the Flutter migrator, unrelated to this feature) turned out to be a
  real prerequisite: stable 22.3.1 needs it under AGP 9's new DSL mode. If
  a future `flutter_local_notifications` upgrade removes that requirement
  (there's a fix on its `master` branch, unreleased as of this writing),
  this note can go.
- **Notification icon**: Android's small-icon guideline needs a flat
  white-on-transparent silhouette; the app's `ic_launcher` mipmaps can't
  be reused. `tool/gen_notification_icon.dart` generates one (a simple
  pixel-grid glyph) at all five densities into
  `android/app/src/main/res/drawable-*/ic_stat_export.png` — rerun it if
  the design should change, don't hand-edit the PNGs.
- **Progress notifications are throttled** (`nextNotifiedPercent` in
  `export_notifier.dart`) to only push a new OS notification when the
  displayed percentage actually changes, not on every one of a long
  export's progress ticks.
- **iOS**: `ios/Runner/AppDelegate.swift` now sets
  `UNUserNotificationCenter.current().delegate = self`, and Swift Package
  Manager resolved `flutter_local_notifications` successfully (confirmed
  via `flutter build ios --simulator`'s package-resolution step). The
  build itself could **not** be fully verified end-to-end in this
  environment (no iOS simulator runtime installed) — that step still
  needs checking on a machine with one, or a real device.
- What Phase 1 explicitly does **not** do: survive the app being
  backgrounded or closed. That's still Phase 2/3 below.

## Phase 2 — Android: survive backgrounding via a foreground service

**Goal:** the export isolate/work keeps running, and the OS keeps the
process alive, while the app is backgrounded or the screen is off — not
just while a dialog is open.

**Why this is a bigger step than Phase 1:** Android only guarantees a
background process stays alive if it's promoted to a **foreground service**
(which mandates showing a persistent notification — so Phase 1's
notification work becomes a hard requirement here, not just a nice-to-have)
with a declared **foreground service type**. Android 14+ (API 34+)
specifically requires declaring which type applies (this app's export
workload is closest to `dataSync` or `mediaProcessing`) or the OS will
throw at runtime when you try to start the service.

**Approach (two reasonable options, pick one and note the choice here once
decided):**
1. Use an existing plugin, e.g. `flutter_foreground_task` — less native
   code to write and maintain, but adds a dependency whose API needs to be
   learned and whose long-term maintenance isn't controlled by this repo.
2. Hand-roll it: a native Kotlin `ForegroundService`
   (`android/app/src/main/kotlin/.../ExportForegroundService.kt`) started
   via a `MethodChannel` from Dart when export begins, stopped when it
   ends; the service owns starting/observing the export work (which means
   either moving the export isolate's entry point to be reachable from
   native-triggered Dart code via a background `FlutterEngine`/
   `DartPluginRegistrant`, or restructuring so the *native* service does the
   heavy lifting — the video/GIF encoding already goes through
   `packages/video_frames` (Kotlin `FrameWriter`), so there's a real
   argument for driving the service from Kotlin directly rather than
   round-tripping through a background Dart isolate).

**Manifest additions needed either way:**
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>
<!-- or FOREGROUND_SERVICE_MEDIA_PROCESSING, depending on which type is declared -->
```
and a `<service android:foregroundServiceType="dataSync" .../>` entry in
`android/app/src/main/AndroidManifest.xml`'s `<application>` block (there is
currently only one `<activity>` there — see that file for the exact
surrounding structure before adding a sibling `<service>`).

**This phase needs a real decision before starting:** does the export
computation itself move into the foreground service (native-driven), or
does the service just keep the process alive while the existing Dart
isolate does the work (Dart-driven, service is a thin wrapper)? The
Dart-driven approach is the smaller diff from today's code but is more
fragile (Android can still throttle/kill Dart isolate execution inside a
backgrounded Flutter engine in ways it won't throttle native service code);
the native-driven approach is more robust but means teaching Kotlin
`FrameWriter`/`ColorConversion` (already used by `video_frames`) to drive
the whole export loop, including calling back into the Dart-side
`bitmapper_core` filter pipeline — which isn't possible from pure Kotlin
(the pipeline is Dart), so in practice **some** background Dart execution
is unavoidable, meaning the "service keeps the engine alive, Dart isolate
does the work" shape is the realistic one. Confirm this reasoning still
holds before implementing — it depends on whether `bitmapper_core` might
ever grow a native path (it doesn't have one today, see
`packages/bitmapper_core`'s "no Flutter dependency" constraint in
`AGENTS.md`, which is a *stronger* constraint than "no native code," but
worth double-checking there's no native filter path planned).

## Phase 3 — iOS: research spike, likely limited

**Goal:** establish what's actually achievable on iOS, then decide the
honest fallback.

iOS does not allow arbitrary long-running background processing the way
Android's foreground services do. The relevant APIs are the `BGTaskScheduler`
family (`BGProcessingTask` for deferrable, longer-running background work,
requested via `BGProcessingTaskRequest`) — but these are **opportunistic**
(the OS decides when to actually run them, often not immediately) and have
execution time budgets, which don't map well onto "user explicitly started
a multi-minute export and wants it to keep running right now." Apple has
also introduced newer/adjacent background-processing APIs in recent iOS
versions; **check current API availability and constraints against the
iOS version this app targets (`IPHONEOS_DEPLOYMENT_TARGET = 15.0` per
`ios/Runner.xcodeproj/project.pbxproj`) at implementation time**, since iOS
background-execution APIs have shifted over time and this doc's author's
knowledge of them may be stale by the time this is picked up.

**Likely honest outcome:** iOS export may need to stay foreground-only,
with a clear in-app message ("keep Bitmapper open while exporting") rather
than a false promise of background completion. That's a legitimate,
honest fallback — don't build a fragile `BGProcessingTask` integration that
mostly doesn't fire in practice just to say background export "exists" on
iOS. Confirm this conclusion (or find a better one) with current Apple
documentation before ruling it out entirely.

## Verification notes for whoever implements this

- Phase 1 (notification content/timing logic) is testable with the existing
  `AppServices` fake-injection pattern.
- Phases 2 and 3 fundamentally need **manual on-device verification**: start
  a long export, background/kill the app, confirm it completes (or, for
  iOS, confirm what actually happens and document it here). This can't be
  confirmed by `flutter test`/`dart test` alone — matches how `AGENTS.md`
  already treats native-build verification (Android build warnings, Kotlin
  unit tests needing a specific JDK, etc.) as something to check for real,
  not assume.
- Whatever ships, update `AGENTS.md`'s "Native builds" section with the new
  manifest entries / service, the same way the Kotlin-built-in-Kotlin
  change was documented there, so this doesn't need re-discovering later.
