import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows export progress as an OS notification while the app is
/// foregrounded. Doesn't survive the app being backgrounded or closed —
/// see docs/plans/background-export.md for that (a separate, later phase,
/// not this one).
abstract class ExportNotifier {
  /// An export started; `title` matches the export dialog's own title
  /// (e.g. "Saving animation").
  Future<void> start(String title);

  /// Progress ticked; called often, implementations should throttle their
  /// own OS-facing updates (see [nextNotifiedPercent]).
  Future<void> progress(int done, int total);

  /// The export finished successfully.
  Future<void> succeed(String message);

  /// The export failed.
  Future<void> fail(String message);

  /// The user cancelled the export.
  Future<void> cancel();
}

/// Does nothing. The default for plain `AppServices(...)` construction, so
/// tests never touch a platform channel that doesn't exist under
/// `flutter_test`. `AppServices.production()` overrides this with
/// [LocalExportNotifier].
class NoopExportNotifier implements ExportNotifier {
  const NoopExportNotifier();

  @override
  Future<void> start(String title) async {}

  @override
  Future<void> progress(int done, int total) async {}

  @override
  Future<void> succeed(String message) async {}

  @override
  Future<void> fail(String message) async {}

  @override
  Future<void> cancel() async {}
}

/// Only worth pushing a new OS notification when the displayed percentage
/// actually changes — otherwise a long export's hundreds of progress ticks
/// would each cost a platform-channel round trip for no visible change.
/// Returns the new percent to show, or `null` if nothing changed since
/// `lastPercent`. `total <= 0` (not yet known) reports 0 once.
int? nextNotifiedPercent(int done, int total, int? lastPercent) {
  final percent = total <= 0 ? 0 : ((done * 100) ~/ total).clamp(0, 100);
  return percent == lastPercent ? null : percent;
}

/// Real implementation, using `flutter_local_notifications`. Lazily
/// initializes on first use (same shape as `PreviewIsolate`'s `_ready`
/// pattern in `filter_controller.dart`) instead of needing an async step
/// in `main()` — which also means the notification permission prompt (on
/// Android 13+) happens at the first real export, not at cold start.
class LocalExportNotifier implements ExportNotifier {
  static const _id = 1;
  static const _channelId = 'export_progress';
  static const _channelName = 'Export progress';
  static const _channelDescription = 'Shows progress while saving a GIF or video.';

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;
  String _title = '';
  int? _lastPercent;

  Future<void> _ensureReady() {
    return _ready ??= () async {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_export'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }();
  }

  NotificationDetails _details({bool showProgress = false, int percent = 0}) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      showProgress: showProgress,
      maxProgress: 100,
      progress: percent,
      onlyAlertOnce: true,
      ongoing: showProgress,
      importance: showProgress ? Importance.low : Importance.defaultImportance,
      autoCancel: !showProgress,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  @override
  Future<void> start(String title) async {
    await _ensureReady();
    _title = title;
    _lastPercent = null;
    await progress(0, 1);
  }

  @override
  Future<void> progress(int done, int total) async {
    await _ensureReady();
    final percent = nextNotifiedPercent(done, total, _lastPercent);
    if (percent == null) return;
    _lastPercent = percent;
    await _plugin.show(
      id: _id,
      title: _title,
      body: '$percent%',
      notificationDetails: _details(showProgress: true, percent: percent),
    );
  }

  @override
  Future<void> succeed(String message) async {
    await _ensureReady();
    await _plugin.show(id: _id, title: _title, body: message, notificationDetails: _details());
  }

  @override
  Future<void> fail(String message) async {
    await _ensureReady();
    await _plugin.show(id: _id, title: _title, body: message, notificationDetails: _details());
  }

  @override
  Future<void> cancel() async {
    await _ensureReady();
    await _plugin.cancel(id: _id);
  }
}
