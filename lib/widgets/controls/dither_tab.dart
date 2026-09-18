import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/editor_model.dart';
import '../../models/labels.dart';
import 'labeled_slider.dart';

class DitherTab extends StatelessWidget {
  const DitherTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editor = context.watch<EditorModel>();
    final config = editor.config;
    // True color skips quantizing, so dithering has nothing to do.
    final active = !editor.trueColor;

    return Win98ScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.ditherMethod),
          Win98Dropdown<String>(
            semanticLabel: l10n.ditherMethod,
            value: config.dither,
            items: [
              for (final m in listDitherMethods())
                Win98DropdownItem(value: m, label: ditherLabel(m)),
            ],
            onChanged: active ? editor.setDither : null,
          ),
          kControlGap,
          LabeledSlider(
            label: l10n.ditherStrength((config.ditherStrength * 100).round()),
            value: config.ditherStrength,
            min: 0,
            max: 1,
            divisions: 20,
            onChanged: active && config.dither != 'none' ? editor.setDitherStrength : null,
          ),
        ],
      ),
    );
  }
}
