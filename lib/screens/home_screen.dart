import 'dart:async';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/editor_model.dart';
import '../models/media_model.dart';
import '../services/app_services.dart';
import '../services/export_actions.dart';
import '../services/filter_controller.dart';
import '../services/image_loader.dart';
import '../widgets/app_menu_bar.dart';
import '../widgets/app_status_bar.dart';
import '../widgets/controls/adjust_tab.dart';
import '../widgets/controls/animation_tab.dart';
import '../widgets/controls/dither_tab.dart';
import '../widgets/controls/effects_tab.dart';
import '../widgets/controls/grid_tab.dart';
import '../widgets/controls/palette_tab.dart';
import '../widgets/controls/presets_tab.dart';
import '../widgets/preview_pane.dart';

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
  late final AppServices _services = context.read<AppServices>();
  late final ExportActions _export = ExportActions(
    isSaving: () => _saving,
    setSaving: (v) => setState(() => _saving = v),
    setMessage: (m) => setState(() => _message = m),
  );

  /// A transient status-bar message (e.g. "Saved ..."), cleared on the next
  /// edit.
  String? _message;
  bool _saving = false;
  StreamSubscription<LoadedMedia>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    _editor.addListener(_rerender);
    _media.addListener(_rerender);
    _services.shareIntentSource.initialShare().then((media) {
      if (media != null && mounted) _loadShared(media);
    });
    _shareSubscription = _services.shareIntentSource.shares().listen(
      _loadShared,
      onError: (Object e) => _reportLoadError(e),
    );
  }

  @override
  void dispose() {
    _editor.removeListener(_rerender);
    _media.removeListener(_rerender);
    _shareSubscription?.cancel();
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
      // While the palette's sample frames are still being decoded, render
      // with this frame's own palette so scrubbing never waits on sampling;
      // MediaModel notifies when the samples are ready and this re-renders.
      final samples = _media.paletteFramesFor(config) ?? const <RgbImage>[];
      animation = AnimationContext(
        frames: samples,
        frameIndex: _media.currentFrame,
        document: _media.document,
      );
    }
    _filter.request(preview, config, animation: animation);
    if (_message != null) setState(() => _message = null);
  }

  /// Open media from the library or the camera, then report anything the
  /// user should know about it (a truncated GIF, video sound that can't be
  /// kept).
  Future<void> _open(MediaRequest request) async {
    try {
      if (!await _media.load(request) || !mounted) return;
      await _reportLoadWarnings();
    } catch (e) {
      await _reportLoadError(e);
    }
  }

  /// Show media shared into the app from another app (the share sheet),
  /// either at cold start or while already running. Ignored while an
  /// export is in progress, since a share can arrive unpredictably and
  /// shouldn't interrupt one.
  Future<void> _loadShared(LoadedMedia media) async {
    if (_saving) return;
    try {
      await _media.loadMedia(media);
      if (!mounted) return;
      await _reportLoadWarnings();
    } catch (e) {
      await _reportLoadError(e);
    }
  }

  /// After a successful load, tell the user about anything they should
  /// know (a truncated GIF, video sound that can't be kept).
  Future<void> _reportLoadWarnings() async {
    final l10n = AppLocalizations.of(context);
    final animation = _media.animation;
    final video = _media.videoInfo;
    final String? warning;
    if (animation != null && animation.truncated) {
      warning = l10n.animationTruncated(animation.frameCount);
    } else if (video != null && video.hasAudio && !video.audioCompatible) {
      warning = l10n.audioUnsupported;
    } else {
      warning = null;
    }
    if (warning != null) {
      await showWin98MessageBox(
        context: context,
        title: l10n.errorTitle,
        message: warning,
        icon: Win98MessageIconType.warning,
        buttons: [l10n.ok],
      );
    }
  }

  Future<void> _reportLoadError(Object e) async {
    debugPrint('Open failed: $e');
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showWin98MessageBox(
      context: context,
      title: l10n.errorTitle,
      message: l10n.errorLoad,
      icon: Win98MessageIconType.error,
      buttons: [l10n.ok],
    );
  }

  /// Ask whether to take a photo or record a video, then open the camera.
  Future<void> _openCamera() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showWin98MessageBox(
      context: context,
      title: l10n.cameraTitle,
      message: l10n.cameraPrompt,
      icon: Win98MessageIconType.question,
      buttons: [l10n.cameraPhoto, l10n.cameraVideo, l10n.cancel],
    );
    switch (choice) {
      case 0:
        await _open(MediaRequest.cameraPhoto);
      case 1:
        await _open(MediaRequest.cameraVideo);
    }
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
    final preview = PreviewPane(onOpen: () => _open(MediaRequest.library), onCamera: _openCamera);

    return Win98Desktop(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Win98Window(
            title: l10n.windowTitle(image.name ?? l10n.untitled),
            expand: true,
            onClose: image.hasImage ? _media.clear : null,
            menuBar: AppMenuBar(
              l10n: l10n,
              onOpen: () => _open(MediaRequest.library),
              onCamera: _openCamera,
              onSave: image.hasImage && !_saving ? () => _export.save(context) : null,
              onClose: image.hasImage ? _media.clear : null,
              onAbout: _about,
            ),
            statusBar: AppStatusBar(l10n: l10n, saving: _saving, message: _message),
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
