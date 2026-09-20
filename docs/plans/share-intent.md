# Receive shared media (share-to-app)

## Status: Phase 1 (Android) shipped. Phase 2 (iOS Share Extension) not
started — needs real Xcode work, see below.

## Where this came from

The user wants to go to the phone's gallery, select a photo or video, tap
Share, and pick Bitmapper — opening the app with that item already loaded,
instead of having to open Bitmapper first and use its own picker.

## Current state (verified by reading the code, not assumed)

- No share-related plugin in `pubspec.yaml` (no `share_plus`,
  `receive_sharing_intent`, `flutter_sharing_intent`, or similar).
- `android/app/src/main/AndroidManifest.xml` has a single `<activity
  android:name=".MainActivity">` with only the launcher `<intent-filter>`
  (`android.intent.action.MAIN` / `android.intent.category.LAUNCHER`). No
  `ACTION_SEND`/`ACTION_SEND_MULTIPLE` filters exist. There's also a
  `<queries>` block for `PROCESS_TEXT` (used by Flutter's own text-selection
  toolbar plugin) — unrelated, don't touch it.
- `ios/Runner/Info.plist` has no `CFBundleDocumentTypes`,
  `UTExportedTypeDeclarations`, or share-extension entries. Only the
  photo/camera/mic usage-description strings and the standard scene
  manifest keys.
- Media loading funnels through one place:
  `lib/services/image_loader.dart` defines `MediaRequest` (`library`,
  `cameraPhoto`, `cameraVideo`) and `PickerImageLoader` (wraps
  `image_picker`), returning a `LoadedMedia` (`LoadedImage`/
  `LoadedAnimation`/`LoadedVideo`), which `MediaModel.load()`
  (`lib/models/media_model.dart`) dispatches into `setImage`/
  `setAnimation`/`openVideo`. Two already-existing helpers do exactly the
  format detection a shared file needs: `decodeMedia(name, bytes)`
  (`image_loader.dart`, handles still-vs-GIF-vs-animated-GIF detection —
  already used internally by `PickerImageLoader.load`) and
  `isVideoFile(name, [mimeType])` (extension/MIME based). A shared video is
  handled by **path** (`LoadedVideo(name, path)`, then
  `MediaModel.openVideo(name, path)`), not bytes — same as how the existing
  picker flow handles video today; don't try to read video bytes directly.

## Phase 1 — Android: receive the share intent — DONE

Shipped with `receive_sharing_intent` (1.9.0), via a new
`ShareIntentSource` abstraction (`lib/services/share_intent_source.dart`)
injected through `AppServices` — same interface/no-op-default/real-impl
shape as `ExportNotifier` from the background-export work. `HomeScreen`
checks `initialShare()` once at startup (cold start) and subscribes to
`shares()` (already running), both routed through one `_loadShared`
helper that reuses `_open`'s exact error-handling
(`showWin98MessageBox`/`l10n.errorLoad`) and warning-reporting
(truncated-GIF / unsupported-audio) logic — those were extracted out of
`_open` into `_reportLoadWarnings`/`_reportLoadError` so both paths share
them instead of duplicating. `MediaModel.load()`'s internal dispatch
switch was extracted into a new public `MediaModel.loadMedia(LoadedMedia)`,
used by both the picker flow and the share flow.

Real-world things found while implementing, worth knowing if you touch
this again:
- **A real compatibility risk was found and worked around, not just
  assumed.** Both candidate packages (`receive_sharing_intent` and
  `share_handler`) have open, unresolved GitHub issues about Flutter's
  built-in-Kotlin migration against this app's exact toolchain (AGP 9.1.0,
  `android.builtInKotlin=true`). A real `flutter build apk --debug` spike
  was run *before* any app-level wiring, specifically to catch this early.
  The actual failure that showed up wasn't the specific GitHub issue
  predicted (a `GeneratedPluginRegistrant` resolution failure) — it was
  simpler: **`receive_sharing_intent` requires `compileSdk = 37`**, one
  version past AGP 9.1.0's own officially-recommended maximum of 36.
  Setting `compileSdk = 37` explicitly in `android/app/build.gradle.kts`
  (instead of the default `flutter.compileSdkVersion`) fixed it, and the
  build has stayed clean since (only the pre-existing, documented
  `flutter_file_dialog` KGP warning shows). This is one version past
  AGP's recommendation, not a hard incompatibility — revisit if a future
  AGP upgrade changes that recommendation, or if this specific combination
  ever causes a real (not just cosmetic) problem.
- **No `SEND_MULTIPLE` filters** — only single-item `ACTION_SEND` for
  `image/*` and `video/*`, matching the user's "a photo or video"
  (singular) framing. `ReceiveSharingIntentSource` also only ever looks at
  `files.first` for the same reason.
- **Cold start vs. live-share both matter and both got tests** — not just
  documented as "needs manual verification" and left there.
  `test/share_intent_test.dart` covers: cold-start load, live-share load,
  a share arriving mid-export being ignored (see the guard note below),
  and a failing shared file showing the same error box `_open` shows.
  `FakeShareIntentSource` (`test/helpers.dart`) makes this possible
  without touching a platform channel.
- **A share can arrive at any time, including mid-export** — unlike a
  deliberate "Open" button tap, so `_loadShared` guards on `_saving` and
  drops the share rather than interrupting an in-progress export. The
  existing picker-triggered `_open` flow does **not** have this guard
  (pre-existing gap, not touched — no bug report about it, out of scope
  here).

**Not done, still real OS-level verification needed:** the actual system
share-sheet flow (sharing from the real Photos app, tapping Bitmapper in
the share sheet) needs a device/emulator and can't be exercised by
`flutter test` — the widget tests above cover the app's own reaction to a
share once received, not the OS delivering one.

## Phase 2 — iOS: Share Extension (needs manual Xcode work)

**This cannot be fully scripted from the repo/CLI.** iOS requires a genuine
**Share Extension** — a separate app target from the main Runner target —
plus an **App Group** to pass the shared file's data between the
extension's process and the main app's process (they're sandboxed
separately; a shared container under the App Group ID is the standard way
to hand off a file).

**Checklist for whoever has Xcode open:**
1. In Xcode, add a new target: File → New → Target → Share Extension. Give
   it a bundle ID following the convention `<main-bundle-id>.ShareExtension`
   (or similar — match whatever this project's existing bundle ID scheme
   is; check `ios/Runner.xcodeproj/project.pbxproj` for the current
   `PRODUCT_BUNDLE_IDENTIFIER` before choosing one).
2. Enable an App Group capability on **both** the Runner target and the new
   extension target, with the same App Group ID (e.g.
   `group.<reverse-domain>.bitmapper`), via Signing & Capabilities in
   Xcode. This requires an Apple Developer account with the right
   permissions — confirm access before starting this phase.
3. In the extension's `Info.plist`, set `NSExtensionActivationRule` to
   accept images and videos (e.g.
   `NSExtensionActivationSupportsImageWithMaxCount` /
   `NSExtensionActivationSupportsMovieWithMaxCount`, or the newer
   predicate-based rule — check current Apple documentation for the
   exact key names/shape, since this has shifted across Xcode versions).
4. The extension's own code (Swift) receives the shared item, writes it
   into the shared App Group container, then needs to signal the main app
   to open and pick it up — the common pattern is the extension opening a
   custom URL scheme (`bitmapper://shared`) that the main app's
   `AppDelegate`/scene delegate handles, reading the file back out of the
   shared container.
5. `receive_sharing_intent` (if chosen for Android in Phase 1) has
   documented iOS setup steps that mirror the above — if using that
   plugin, follow its README's iOS instructions exactly rather than
   reinventing the App Group / URL scheme wiring, since it likely already
   implements the handoff.

**What can be prepared ahead of time (Dart side, no Xcode needed):** the
same `MediaModel` integration point from Phase 1 (whatever shape step 3
took) is reusable as-is for iOS — the OS-level delivery mechanism differs,
but once a shared file's path/bytes reach Dart, the rest of the pipeline
(`decodeMedia`/`isVideoFile`/`setImage`/`setAnimation`/`openVideo`) is
identical. So Phase 1's `MediaModel` work is not throwaway even before
Phase 2's Xcode work happens.

## Verification

- Android: install a debug build, share an image and a video from the
  system Photos app to Bitmapper, confirm both cold-start and
  already-running cases open the right media.
- iOS: same, after the Share Extension exists — needs a real device or
  simulator with Xcode, and can't be verified via `flutter test`.
- Update `CLAUDE.md`'s "Video in the app"/media-loading section once this
  lands, describing the new entry point the same way `MediaModel.load` is
  documented today.
