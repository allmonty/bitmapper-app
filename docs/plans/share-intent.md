# Receive shared media (share-to-app)

## Status: not started

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

## Phase 1 — Android: receive the share intent

**Approach:**
1. Add a share-receiving plugin — `receive_sharing_intent` is the common
   choice (handles both "cold start via share" and "already-running, share
   again" cases, and returns a stream of shared file paths/mime types).
   Verify it's still maintained and compatible with this app's Flutter
   version (`.tool-versions`: `flutter 3.47.5-stable`) before committing to
   it; if it's stale, a hand-rolled `MethodChannel` reading the intent in
   `MainActivity.kt`/`MainActivity` is the fallback (more code, no
   third-party dependency risk).
2. Add intent filters to the existing `<activity android:name=".MainActivity">`
   block in `AndroidManifest.xml` (alongside the current launcher filter,
   as a **second** `<intent-filter>` — don't merge them into one, since
   `MAIN`/`LAUNCHER` and `SEND` are semantically different entry points):
   ```xml
   <intent-filter>
       <action android:name="android.intent.action.SEND"/>
       <category android:name="android.intent.category.DEFAULT"/>
       <data android:mimeType="image/*"/>
   </intent-filter>
   <intent-filter>
       <action android:name="android.intent.action.SEND"/>
       <category android:name="android.intent.category.DEFAULT"/>
       <data android:mimeType="video/*"/>
   </intent-filter>
   ```
   (Separate filters per mime type, matching common Android convention —
   a single filter with multiple `<data>` tags works too but is easier to
   get subtly wrong with wildcard matching; verify against the chosen
   plugin's own setup instructions, which may prescribe a specific shape.)
   Add `ACTION_SEND_MULTIPLE` filters too only if multi-file sharing is
   actually wanted (the user's ask was "select a photo or video" —
   singular — so this may be unnecessary scope; confirm before adding it).
3. Wire the received path into `MediaModel`. The cleanest integration point
   is a **new `ImageLoader`-shaped path**, not a special case bolted onto
   `MediaModel`: since `PickerImageLoader.load()` already does "given
   bytes/path, figure out still vs. GIF vs. video and produce the right
   `LoadedMedia`," a shared file should go through the same logic. Two
   reasonable shapes:
   - Add a method to `MediaModel` like `Future<void> loadShared(String path)`
     that reads the file, calls `isVideoFile`/`decodeMedia` exactly as
     `PickerImageLoader.load` does internally, and calls
     `setImage`/`setAnimation`/`openVideo` accordingly — duplicates a little
     of `PickerImageLoader`'s logic but keeps `ImageLoader`'s existing
     `MediaRequest`-based contract untouched.
   - Or extract `PickerImageLoader`'s "given bytes+name (or path), produce
     `LoadedMedia`" logic into a standalone function reusable by both the
     picker and a new share-intent path, then have `MediaModel` call that
     function directly for a shared file. This is more refactoring but
     avoids near-duplicate logic. Prefer this if the duplication in the
     first option ends up more than a few lines.
   Either way, this is app-state plumbing (`lib/models/`), not something
   that belongs in `bitmapper_core` (which must stay Flutter-free) or
   `win98_ui`.
4. Handle both app states the chosen plugin needs to distinguish: **cold
   start** (app wasn't running, launched fresh via the share action —
   typically delivered through a plugin-specific "initial media" getter/
   stream that needs to be checked once at app startup, e.g. in
   `main.dart` or `HomeScreen`'s `initState`) and **already running**
   (delivered via a stream/callback while the app is alive). Test both
   manually on a device/emulator — this is OS-intent plumbing that
   `flutter test`'s widget tests can't exercise.

**Tests:** the format-detection and `MediaModel` state-transition logic
(whatever shape it takes, per step 3 above) is unit-testable the same way
existing `MediaModel` tests work (see `test/animation_test.dart`'s
`MediaModel with animations` group and `test/helpers.dart`'s
`FakeImageLoader`) — a fake "shared media source" can be injected the same
way. The actual OS-level intent delivery cannot be unit-tested and needs
manual verification.

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
