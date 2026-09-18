import 'dart:io';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/editor_model.dart';
import '../models/media_model.dart';
import '../models/presets_model.dart';
import '../services/animation_exporter.dart';
import '../services/app_services.dart';
import '../services/filter_controller.dart';
import '../services/image_loader.dart';
import '../services/image_saver.dart';
import '../services/video_exporter.dart';
import '../widgets/controls/adjust_tab.dart';
import '../widgets/controls/animation_tab.dart';
import '../widgets/controls/dither_tab.dart';
import '../widgets/controls/effects_tab.dart';
import '../widgets/controls/grid_tab.dart';
import '../widgets/controls/palette_tab.dart';
import '../widgets/controls/presets_tab.dart';
import '../widgets/preview_pane.dart';

/// Delete a temporary file, ignoring errors.
void deleteQuietly(String path) {
  try {
    File(path).deleteSync();
  } catch (_) {}
}

const kAppVersion = '1.0.0';

/// The single, maximized "Bitmapper" window: menu bar, preview, control
/// tabs and status bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final EditorModel _editor = context.read<EditorModel>();
  late final MediaModel _media = context.read<MediaModel>();
  late final FilterController _filter = context.read<FilterController>();

  /// A transient status-bar message (e.g. "Saved ..."), cleared on the next
  /// edit.
  String? _message;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _editor.addListener(_rerender);
    _media.addListener(_rerender);
  }

  @override
  void dispose() {
    _editor.removeListener(_rerender);
    _media.removeListener(_rerender);
    super.dispose();
  }

  /// Keep the preview in sync with the settings and the loaded media (and,
  /// for animations, the frame being scrubbed).
  void _rerender() {
    final preview = _media.preview;
    if (preview == null) {
      if (_filter.result != null || _filter.busy) _filter.clear();
      return;
    }
    final config = _editor.configFor(preview.width, preview.height);
    AnimationContext? animation;
    if (_media.isAnimation) {
      animation = AnimationContext(
        frames: _media.animation!.frames,
        frameIndex: _media.currentFrame,
      );
    } else if (_media.isVideo) {
      final samples = _videoPaletteFrames(config);
      if (samples == null) return; // sampling; MediaModel notifies when ready
      animation = AnimationContext(
        frames: samples,
        frameIndex: _media.currentFrame,
        document: _media.document,
      );
    }
    _filter.request(preview, config, animation: animation);
    if (_message != null) setState(() => _message = null);
  }

  /// The video frames the shared palette is built from for `config` (none
  /// for per-frame or non-auto palettes), or null while they're decoded.
  List<RgbImage>? _videoPaletteFrames(BitmapFilterConfig config) {
    if (!needsSequencePalette(config)) return const [];
    return switch (config.paletteStrategy) {
      PaletteStrategy.perFrame => const [],
      PaletteStrategy.firstFrame => _media.paletteSamples(1),
      PaletteStrategy.sampled => _media.paletteSamples(config.paletteSamples),
    };
  }

  Future<void> _open(ImageOrigin origin) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _media.load(origin);
      final animation = _media.animation;
      if (animation != null && animation.truncated && mounted) {
        await showWin98MessageBox(
          context: context,
          title: l10n.errorTitle,
          message: l10n.animationTruncated(animation.frameCount),
          icon: Win98MessageIconType.warning,
          buttons: [l10n.ok],
        );
      }
    } catch (e) {
      debugPrint('Image load failed: $e');
      if (!mounted) return;
      await showWin98MessageBox(
        context: context,
        title: l10n.errorTitle,
        message: l10n.errorLoad,
        icon: Win98MessageIconType.error,
        buttons: [l10n.ok],
      );
    }
  }

  Future<void> _openVideo() async {
    final l10n = AppLocalizations.of(context);
    try {
      final loaded = await _media.loadVideo();
      final info = _media.videoInfo;
      if (loaded && info != null && info.hasAudio && !info.audioCompatible && mounted) {
        await showWin98MessageBox(
          context: context,
          title: l10n.errorTitle,
          message: l10n.audioUnsupported,
          icon: Win98MessageIconType.warning,
          buttons: [l10n.ok],
        );
      }
    } catch (e) {
      debugPrint('Video load failed: $e');
      if (!mounted) return;
      await showWin98MessageBox(
        context: context,
        title: l10n.errorTitle,
        message: l10n.errorVideo,
        icon: Win98MessageIconType.error,
        buttons: [l10n.ok],
      );
    }
  }

  Future<void> _save() => switch (_media.kind) {
    MediaKind.animation => _saveAnimation(),
    MediaKind.video => _saveVideo(),
    _ => _saveStill(),
  };

  Future<void> _saveStill() async {
    final full = _media.full;
    final preview = _media.preview;
    if (full == null || preview == null || _saving) return;
    final l10n = AppLocalizations.of(context);
    final services = context.read<AppServices>();
    final navigator = Navigator.of(context);
    // Same grid as the preview, rendered at the source's full size.
    final config = _editor.configFor(preview.width, preview.height);

    setState(() => _saving = true);
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
      final result = await _filter.renderFull(full, config);
      final png = await services.pngEncoder(result.output);
      closeDialog();
      final fileName = exportFileName(services.clock());
      final saved = await services.imageSaver.save(png, fileName);
      if (mounted && saved != null) setState(() => _message = l10n.statusSaved(fileName));
    } catch (e) {
      debugPrint('Save failed: $e');
      closeDialog();
      if (mounted) {
        await showWin98MessageBox(
          context: context,
          title: l10n.errorTitle,
          message: l10n.errorSave,
          icon: Win98MessageIconType.error,
          buttons: [l10n.ok],
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Filter every frame of the GIF on a worker isolate and save an animated
  /// GIF.
  Future<void> _saveAnimation() async {
    final bytes = _media.animationBytes;
    final frame = _media.preview;
    if (bytes == null || frame == null || _saving) return;
    final l10n = AppLocalizations.of(context);
    final services = context.read<AppServices>();
    final job = GifExportJob(
      gifBytes: bytes,
      config: _editor.configFor(frame.width, frame.height),
      size: _editor.gifSize,
    );
    await _runExport<GifExportResult>(
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

  /// Run an export with a progress dialog whose Cancel (or close box) stops
  /// it, then `save` the result; `save` returns the status message, or null
  /// if the user cancelled the save dialog.
  Future<void> _runExport<T>({
    required String title,
    required ExportTask<T> Function(ProgressCallback onProgress) start,
    required Future<String?> Function(T result) save,
  }) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final progress = ValueNotifier<(int, int)?>(null);

    setState(() => _saving = true);
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
      if (mounted && message != null) setState(() => _message = message);
    } on ExportCancelled {
      closeDialog();
    } catch (e) {
      debugPrint('Export failed: $e');
      closeDialog();
      if (mounted) {
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
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Filter a whole video on a worker isolate into an MP4 (sound copied
  /// through) or a GIF, then hand it to the save dialog.
  Future<void> _saveVideo() async {
    final path = _media.videoPath;
    final frame = _media.preview;
    if (path == null || frame == null || _saving) return;
    final config = _editor.configFor(frame.width, frame.height);
    final paletteFrames = _videoPaletteFrames(config);
    if (paletteFrames == null) return; // still sampling; try again shortly
    final l10n = AppLocalizations.of(context);
    final services = context.read<AppServices>();
    final format = _editor.videoFormat;
    final job = VideoExportJob(
      inputPath: path,
      outputPath: tempVideoPath(services.clock()),
      config: config,
      paletteFrames: paletteFrames,
      format: format,
      mp4Resolution: _editor.mp4Resolution,
      gifSize: _editor.gifSize,
      gifFrameRate: _editor.gifFrameRate,
    );
    await _runExport<VideoExportResult>(
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

  void _about() {
    final l10n = AppLocalizations.of(context);
    showWin98MessageBox(
      context: context,
      title: l10n.aboutTitle,
      message: l10n.aboutBody(kAppVersion),
      buttons: [l10n.ok],
    );
  }

  Win98MenuBar _menuBar(AppLocalizations l10n, bool hasImage) {
    final presets = context.watch<PresetsModel>();
    return Win98MenuBar(
      menus: [
        Win98Menu(
          label: l10n.menuFile,
          items: [
            Win98MenuItem(label: l10n.menuOpen, onSelected: () => _open(ImageOrigin.gallery)),
            Win98MenuItem(label: l10n.menuCamera, onSelected: () => _open(ImageOrigin.camera)),
            Win98MenuItem(label: l10n.menuOpenVideo, onSelected: _openVideo),
            Win98MenuItem(label: l10n.menuSave, onSelected: hasImage && !_saving ? _save : null),
            const Win98MenuDivider(),
            Win98MenuItem(label: l10n.menuClose, onSelected: hasImage ? _media.clear : null),
          ],
        ),
        Win98Menu(
          label: l10n.menuPresets,
          items: [
            for (final p in presets.all)
              Win98MenuItem(label: p.name, onSelected: () => _editor.applyPreset(p)),
            const Win98MenuDivider(),
            Win98MenuItem(label: l10n.menuSavePreset, onSelected: () => savePresetFlow(context)),
          ],
        ),
        Win98Menu(
          label: l10n.menuHelp,
          items: [Win98MenuItem(label: l10n.menuAbout, onSelected: _about)],
        ),
      ],
    );
  }

  Win98StatusBar _statusBar(AppLocalizations l10n) {
    final image = context.watch<MediaModel>();
    final filter = context.watch<FilterController>();
    final editor = context.watch<EditorModel>();
    final preview = image.preview;

    final String status;
    if (_saving) {
      status = l10n.statusSaving;
    } else if (image.sampling) {
      status = l10n.statusSampling;
    } else if (image.loading || filter.busy) {
      status = l10n.statusWorking;
    } else if (filter.error != null) {
      status = l10n.errorFilter;
    } else {
      status =
          _message ??
          switch (preview) {
            null => l10n.statusNoImage,
            _ when image.isSequence && editor.isErrorDiffusion => l10n.statusShimmer,
            _ => l10n.statusReady,
          };
    }

    // The message pane takes the slack; the stats panes size to their text.
    final panes = [Win98StatusPane(Text(status))];
    if (preview != null) {
      final config = editor.configFor(preview.width, preview.height);
      final result = filter.result;
      final ms = filter.lastDuration?.inMilliseconds;
      panes.addAll([
        Win98StatusPane(Text(l10n.statusCells(config.gridCols, config.gridRows)), flex: 0),
        if (result != null)
          Win98StatusPane(Text(l10n.statusColors(_usedColors(result.grid.data))), flex: 0),
        if (ms != null) Win98StatusPane(Text(l10n.statusMs(ms)), flex: 0),
      ]);
    }
    return Win98StatusBar(panes: panes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final image = context.watch<MediaModel>();

    final tabs = Win98TabView(
      tabs: [
        Win98Tab(label: l10n.tabPalette, builder: (_) => const PaletteTab()),
        Win98Tab(label: l10n.tabDither, builder: (_) => const DitherTab()),
        Win98Tab(label: l10n.tabGrid, builder: (_) => const GridTab()),
        Win98Tab(label: l10n.tabAdjust, builder: (_) => const AdjustTab()),
        Win98Tab(label: l10n.tabEffects, builder: (_) => const EffectsTab()),
        if (image.isSequence)
          Win98Tab(label: l10n.tabAnimation, builder: (_) => const AnimationTab()),
        Win98Tab(label: l10n.tabPresets, builder: (_) => const PresetsTab()),
      ],
    );
    final preview = PreviewPane(
      onGallery: () => _open(ImageOrigin.gallery),
      onCamera: () => _open(ImageOrigin.camera),
      onVideo: _openVideo,
    );

    return Win98Desktop(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Win98Window(
            title: l10n.windowTitle(image.name ?? l10n.untitled),
            expand: true,
            onClose: image.hasImage ? _media.clear : null,
            menuBar: _menuBar(l10n, image.hasImage),
            statusBar: _statusBar(l10n),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Side by side in landscape, stacked in portrait.
                if (constraints.maxWidth > constraints.maxHeight * 1.2) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: preview),
                      const SizedBox(width: 6),
                      Expanded(flex: 2, child: tabs),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: preview),
                    const SizedBox(height: 6),
                    Expanded(flex: 4, child: tabs),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

int _usedColors(List<int> rgb) {
  final seen = <int>{};
  for (var i = 0; i < rgb.length; i += 3) {
    seen.add((rgb[i] << 16) | (rgb[i + 1] << 8) | rgb[i + 2]);
  }
  return seen.length;
}
