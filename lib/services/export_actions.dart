import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/editor_model.dart';
import '../models/media_model.dart';
import '../services/animation_exporter.dart';
import '../services/app_services.dart';
import '../services/filter_controller.dart';
import '../services/image_saver.dart';
import '../services/video_exporter.dart';

/// The save/export flows: still image, animated GIF and video. Reads
/// [MediaModel]/[EditorModel]/[FilterController]/[AppServices] from
/// `context` on each call rather than holding them, since methods here are
/// only ever invoked from a live widget tree (a menu item or button).
class ExportActions {
  ExportActions({required this.isSaving, required this.setSaving, required this.setMessage});

  /// Whether a save/export is already in progress (guards against a
  /// double-tap starting a second one).
  final bool Function() isSaving;
  final void Function(bool) setSaving;

  /// Set the transient status-bar message (or clear it with null).
  final void Function(String?) setMessage;

  Future<void> save(BuildContext context) {
    final media = context.read<MediaModel>();
    return switch (media.kind) {
      MediaKind.animation => saveAnimation(context),
      MediaKind.video => saveVideo(context),
      _ => saveStill(context),
    };
  }

  Future<void> saveStill(BuildContext context) async {
    final media = context.read<MediaModel>();
    final editor = context.read<EditorModel>();
    final filter = context.read<FilterController>();
    final full = media.full;
    final preview = media.preview;
    if (full == null || preview == null || isSaving()) return;
    final l10n = AppLocalizations.of(context);
    final services = context.read<AppServices>();
    final navigator = Navigator.of(context);
    // Same grid as the preview, rendered at the source's full size.
    final config = editor.configFor(preview.width, preview.height);

    setSaving(true);
    var dialogOpen = true;
    showWin98Dialog<void>(
      context: context,
      title: l10n.savingTitle,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(l10n.savingBody), const SizedBox(height: 10), const Win98ProgressBar()],
      ),
    ).whenComplete(() => dialogOpen = false);

    void closeDialog() {
      if (dialogOpen) navigator.pop();
    }

    try {
      final result = await filter.renderFull(full, config);
      final png = await services.pngEncoder(result.output);
      closeDialog();
      final fileName = exportFileName(services.clock());
      final saved = await services.imageSaver.save(png, fileName);
      if (context.mounted && saved != null) setMessage(l10n.statusSaved(fileName));
    } catch (e) {
      debugPrint('Save failed: $e');
      closeDialog();
      if (context.mounted) {
        await showWin98MessageBox(
          context: context,
          title: l10n.errorTitle,
          message: l10n.errorSave,
          icon: Win98MessageIconType.error,
          buttons: [l10n.ok],
        );
      }
    } finally {
      if (context.mounted) setSaving(false);
    }
  }

  /// Filter every frame of the GIF on a worker isolate and save an animated
  /// GIF.
  Future<void> saveAnimation(BuildContext context) async {
    final media = context.read<MediaModel>();
    final editor = context.read<EditorModel>();
    final bytes = media.animationBytes;
    final frame = media.preview;
    if (bytes == null || frame == null || isSaving()) return;
    final l10n = AppLocalizations.of(context);
    final services = context.read<AppServices>();
    final job = GifExportJob(
      gifBytes: bytes,
      config: editor.configFor(frame.width, frame.height),
      size: editor.gifSize,
    );
    await _runExport<GifExportResult>(
      context: context,
      title: l10n.exportTitle,
      start: (onProgress) => services.gifExporter(job, onProgress),
      save: (result) async {
        final fileName = exportFileName(services.clock(), extension: 'gif');
        final saved = await services.imageSaver.save(result.bytes, fileName, mimeType: 'image/gif');
        if (saved == null) return null;
        return result.lossyFrames > 0
            ? l10n.statusSavedLossy(fileName)
            : l10n.statusSaved(fileName);
      },
    );
  }

  /// Filter a whole video on a worker isolate into an MP4 (sound copied
  /// through) or a GIF, then hand it to the save dialog.
  Future<void> saveVideo(BuildContext context) async {
    final media = context.read<MediaModel>();
    final editor = context.read<EditorModel>();
    final path = media.videoPath;
    final frame = media.preview;
    if (path == null || frame == null || isSaving()) return;
    final config = editor.configFor(frame.width, frame.height);
    final paletteFrames = media.paletteFramesFor(config);
    if (paletteFrames == null) return; // still sampling; try again shortly
    final l10n = AppLocalizations.of(context);
    final services = context.read<AppServices>();
    final format = editor.videoFormat;
    final job = VideoExportJob(
      inputPath: path,
      outputPath: tempVideoPath(services.clock()),
      config: config,
      paletteFrames: paletteFrames,
      format: format,
      mp4Resolution: editor.mp4Resolution,
      gifSize: editor.gifSize,
      gifFrameRate: editor.gifFrameRate,
    );
    await _runExport<VideoExportResult>(
      context: context,
      title: l10n.exportVideoTitle,
      start: (onProgress) => services.videoExporter(job, onProgress),
      save: (result) async {
        final gif = format == VideoFormat.gif;
        final fileName = exportFileName(services.clock(), extension: gif ? 'gif' : 'mp4');
        final String? saved;
        if (gif) {
          saved = await services.imageSaver.save(result.gifBytes!, fileName, mimeType: 'image/gif');
        } else {
          try {
            saved = await services.imageSaver.saveFile(
              result.path!,
              fileName,
              mimeType: 'video/mp4',
            );
          } finally {
            deleteQuietly(result.path!);
          }
        }
        if (saved == null) return null;
        if (result.audioDropped) return l10n.statusSavedNoSound(fileName);
        return result.lossyFrames > 0
            ? l10n.statusSavedLossy(fileName)
            : l10n.statusSaved(fileName);
      },
    );
  }

  /// Run an export with a progress dialog whose Cancel (or close box) stops
  /// it, then `save` the result; `save` returns the status message, or null
  /// if the user cancelled the save dialog.
  Future<void> _runExport<T>({
    required BuildContext context,
    required String title,
    required ExportTask<T> Function(ProgressCallback onProgress) start,
    required Future<String?> Function(T result) save,
  }) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final progress = ValueNotifier<(int, int)?>(null);

    setSaving(true);
    final task = start((done, total) => progress.value = (done, total));

    var dialogOpen = true;
    showWin98Dialog<void>(
      context: context,
      title: title,
      builder: (context) => ValueListenableBuilder<(int, int)?>(
        valueListenable: progress,
        builder: (context, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(value == null ? l10n.exportPreparing : l10n.exportProgress(value.$1, value.$2)),
            const SizedBox(height: 10),
            Win98ProgressBar(value: value == null ? null : value.$1 / value.$2),
            Win98DialogButtons(
              children: [
                Win98Button(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // Cancel, or the title bar's close button, stops the export.
      dialogOpen = false;
      task.cancel();
    });

    void closeDialog() {
      if (dialogOpen) navigator.pop();
    }

    try {
      final result = await task.result;
      closeDialog();
      final message = await save(result);
      if (context.mounted && message != null) setMessage(message);
    } on ExportCancelled {
      closeDialog();
    } catch (e) {
      debugPrint('Export failed: $e');
      closeDialog();
      if (context.mounted) {
        await showWin98MessageBox(
          context: context,
          title: l10n.errorTitle,
          message: l10n.errorSave,
          icon: Win98MessageIconType.error,
          buttons: [l10n.ok],
        );
      }
    } finally {
      progress.dispose();
      if (context.mounted) setSaving(false);
    }
  }
}
