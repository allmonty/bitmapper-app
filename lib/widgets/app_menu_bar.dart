import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/editor_model.dart';
import '../models/presets_model.dart';
import 'controls/presets_tab.dart' show savePresetFlow;

/// The window's menu bar: File (open/camera/save/close), Presets (apply or
/// save one) and Help (about).
class AppMenuBar extends StatelessWidget {
  const AppMenuBar({
    super.key,
    required this.l10n,
    required this.onOpen,
    required this.onCamera,
    required this.onSave,
    required this.onClose,
    required this.onAbout,
  });

  final AppLocalizations l10n;
  final VoidCallback onOpen;
  final VoidCallback onCamera;

  /// Null disables the menu item (no image, or already saving).
  final VoidCallback? onSave;

  /// Null disables the menu item (no image loaded).
  final VoidCallback? onClose;

  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final presets = context.watch<PresetsModel>();
    final editor = context.read<EditorModel>();
    return Win98MenuBar(
      menus: [
        Win98Menu(
          label: l10n.menuFile,
          items: [
            Win98MenuItem(label: l10n.menuOpen, onSelected: onOpen),
            Win98MenuItem(label: l10n.menuCamera, onSelected: onCamera),
            Win98MenuItem(label: l10n.menuSave, onSelected: onSave),
            const Win98MenuDivider(),
            Win98MenuItem(label: l10n.menuClose, onSelected: onClose),
          ],
        ),
        Win98Menu(
          label: l10n.menuPresets,
          // Built-ins alone are well past two dozen; capped and scrollable
          // instead of the panel covering most of the window.
          maxHeight: 400,
          items: [
            for (final p in presets.all)
              Win98MenuItem(label: p.name, onSelected: () => editor.applyPreset(p)),
            const Win98MenuDivider(),
            Win98MenuItem(label: l10n.menuSavePreset, onSelected: () => savePresetFlow(context)),
          ],
        ),
        Win98Menu(
          label: l10n.menuHelp,
          items: [Win98MenuItem(label: l10n.menuAbout, onSelected: onAbout)],
        ),
      ],
    );
  }
}
