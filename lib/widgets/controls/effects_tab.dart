import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/editor_model.dart';
import 'labeled_slider.dart';

class EffectsTab extends StatelessWidget {
  const EffectsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editor = context.watch<EditorModel>();
    final scanlines = editor.config.scanlines;

    return Win98ScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledSlider(
            label: l10n.effectScanlines((scanlines * 100).round()),
            value: scanlines,
            min: 0,
            max: 1,
            divisions: 20,
            onChanged: editor.setScanlines,
          ),
        ],
      ),
    );
  }
}
