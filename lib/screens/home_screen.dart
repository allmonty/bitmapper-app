import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/editor_model.dart';
import '../models/image_model.dart';
import '../models/presets_model.dart';
import '../services/app_services.dart';
import '../services/filter_controller.dart';
import '../services/image_loader.dart';
import '../services/image_saver.dart';
import '../widgets/controls/adjust_tab.dart';
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
  late final ImageModel _image = context.read<ImageModel>();
  late final FilterController _filter = context.read<FilterController>();

  /// A transient status-bar message (e.g. "Saved ..."), cleared on the next
  /// edit.
  String? _message;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _editor.addListener(_rerender);
    _image.addListener(_rerender);
  }

  @override
  void dispose() {
    _editor.removeListener(_rerender);
    _image.removeListener(_rerender);
    super.dispose();
  }

  /// Keep the preview in sync with the settings and the loaded image.
  void _rerender() {
    final preview = _image.preview;
    if (preview == null) {
      if (_filter.result != null || _filter.busy) _filter.clear();
      return;
    }
    _filter.request(preview, _editor.configFor(preview.width, preview.height));
    if (_message != null) setState(() => _message = null);
  }

  Future<void> _open(ImageOrigin origin) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _image.load(origin);
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

  Future<void> _save() async {
    final full = _image.full;
    final preview = _image.preview;
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
            Win98MenuItem(label: l10n.menuSave, onSelected: hasImage && !_saving ? _save : null),
            const Win98MenuDivider(),
            Win98MenuItem(label: l10n.menuClose, onSelected: hasImage ? _image.clear : null),
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
    final image = context.watch<ImageModel>();
    final filter = context.watch<FilterController>();
    final editor = context.watch<EditorModel>();
    final preview = image.preview;

    final String status;
    if (_saving) {
      status = l10n.statusSaving;
    } else if (image.loading || filter.busy) {
      status = l10n.statusWorking;
    } else if (filter.error != null) {
      status = l10n.errorFilter;
    } else {
      status = _message ?? (preview == null ? l10n.statusNoImage : l10n.statusReady);
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
    final image = context.watch<ImageModel>();

    final tabs = Win98TabView(
      tabs: [
        Win98Tab(label: l10n.tabPalette, builder: (_) => const PaletteTab()),
        Win98Tab(label: l10n.tabDither, builder: (_) => const DitherTab()),
        Win98Tab(label: l10n.tabGrid, builder: (_) => const GridTab()),
        Win98Tab(label: l10n.tabAdjust, builder: (_) => const AdjustTab()),
        Win98Tab(label: l10n.tabEffects, builder: (_) => const EffectsTab()),
        Win98Tab(label: l10n.tabPresets, builder: (_) => const PresetsTab()),
      ],
    );
    final preview = PreviewPane(
      onGallery: () => _open(ImageOrigin.gallery),
      onCamera: () => _open(ImageOrigin.camera),
    );

    return Win98Desktop(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Win98Window(
            title: l10n.windowTitle(image.name ?? l10n.untitled),
            expand: true,
            onClose: image.hasImage ? _image.clear : null,
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
