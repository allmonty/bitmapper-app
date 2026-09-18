import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/editor_model.dart';
import '../../models/preset.dart';
import '../../models/presets_model.dart';
import '../prompt_dialog.dart';

/// Pick, save, rename and delete presets. Built-ins are read-only.
class PresetsTab extends StatefulWidget {
  const PresetsTab({super.key});

  @override
  State<PresetsTab> createState() => _PresetsTabState();
}

class _PresetsTabState extends State<PresetsTab> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final presets = context.watch<PresetsModel>();
    final selected = _selectedId == null ? null : presets.byId(_selectedId!);
    final editable = selected != null && !selected.builtIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Win98ListBox<String>(
            height: null,
            items: [
              for (final p in presets.all)
                Win98ListItem(value: p.id, label: p.builtIn ? l10n.presetBuiltIn(p.name) : p.name),
            ],
            selected: _selectedId,
            onSelected: (id) => setState(() => _selectedId = id),
            onActivated: (id) => _apply(presets.byId(id)),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Win98Button(
              isDefault: true,
              onPressed: selected == null ? null : () => _apply(selected),
              child: Text(l10n.presetsApply),
            ),
            Win98Button(onPressed: () => savePresetFlow(context), child: Text(l10n.presetsSave)),
            Win98Button(
              onPressed: editable ? () => _rename(selected) : null,
              child: Text(l10n.presetsRename),
            ),
            Win98Button(
              onPressed: editable ? () => _delete(selected) : null,
              child: Text(l10n.presetsDelete),
            ),
          ],
        ),
      ],
    );
  }

  void _apply(AppPreset? preset) {
    if (preset != null) context.read<EditorModel>().applyPreset(preset);
  }

  Future<void> _rename(AppPreset preset) async {
    final l10n = AppLocalizations.of(context);
    final presets = context.read<PresetsModel>();
    final name = await showTextPrompt(
      context: context,
      title: l10n.renameTitle,
      prompt: l10n.presetNamePrompt,
      initial: preset.name,
    );
    if (name != null) await presets.rename(preset.id, name);
  }

  Future<void> _delete(AppPreset preset) async {
    final l10n = AppLocalizations.of(context);
    final presets = context.read<PresetsModel>();
    final answer = await showWin98MessageBox(
      context: context,
      title: l10n.deleteTitle,
      message: l10n.deleteConfirm(preset.name),
      icon: Win98MessageIconType.question,
      buttons: [l10n.yes, l10n.no],
    );
    if (answer == 0) {
      await presets.remove(preset.id);
      if (mounted) setState(() => _selectedId = null);
    }
  }
}

/// Ask for a name and save the current settings as a user preset.
Future<void> savePresetFlow(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final presets = context.read<PresetsModel>();
  final config = context.read<EditorModel>().config;
  final name = await showTextPrompt(
    context: context,
    title: l10n.presetNameTitle,
    prompt: l10n.presetNamePrompt,
    initial: l10n.presetDefaultName,
  );
  if (name != null) await presets.add(name, config);
}
