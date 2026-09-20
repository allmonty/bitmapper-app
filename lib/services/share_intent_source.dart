import 'dart:async';
import 'dart:io';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'image_loader.dart';

/// Media the OS handed to the app via its share sheet, outside the normal
/// picker flow (Android's `ACTION_SEND` — see
/// `android/app/src/main/AndroidManifest.xml`; iOS needs a Share Extension,
/// not implemented yet — see docs/plans/share-intent.md).
abstract class ShareIntentSource {
  /// Non-null if the app was cold-started by a share. Call once, at
  /// startup.
  Future<LoadedMedia?> initialShare();

  /// Fires for a share received while the app is already running.
  Stream<LoadedMedia> shares();
}

/// Does nothing. The default for plain `AppServices(...)` construction, so
/// tests never touch a platform channel `flutter_test` doesn't have.
/// `AppServices.production()` overrides this with
/// [ReceiveSharingIntentSource].
class NoopShareIntentSource implements ShareIntentSource {
  const NoopShareIntentSource();

  @override
  Future<LoadedMedia?> initialShare() async => null;

  @override
  Stream<LoadedMedia> shares() => const Stream.empty();
}

/// Real implementation, using `receive_sharing_intent`. Bitmapper edits one
/// item at a time, so only the first shared file is used if more than one
/// was shared at once (the manifest only registers single-item `SEND`
/// filters anyway, not `SEND_MULTIPLE`).
class ReceiveSharingIntentSource implements ShareIntentSource {
  @override
  Future<LoadedMedia?> initialShare() async {
    final files = await ReceiveSharingIntent.instance.getInitialMedia();
    await ReceiveSharingIntent.instance.reset();
    if (files.isEmpty) return null;
    return _toLoadedMedia(files.first);
  }

  @override
  Stream<LoadedMedia> shares() => ReceiveSharingIntent.instance
      .getMediaStream()
      .where((files) => files.isNotEmpty)
      .asyncMap((files) => _toLoadedMedia(files.first));

  static Future<LoadedMedia> _toLoadedMedia(SharedMediaFile file) async {
    // receive_sharing_intent copies shared files to a temp cache folder and
    // hands back that path, so no content:// URI resolution is needed here.
    final name = file.path.split(Platform.pathSeparator).last;
    if (file.type == SharedMediaType.video || isVideoFile(name, file.mimeType)) {
      return LoadedVideo(name: name, path: file.path);
    }
    return decodeMedia(name, await File(file.path).readAsBytes());
  }
}
