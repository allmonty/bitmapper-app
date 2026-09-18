import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/editor_model.dart';
import 'labeled_slider.dart';

class GridTab extends StatelessWidget {
  const GridTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editor = context.watch<EditorModel>();
    final config = editor.config;

    return Win98ScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledSlider(
            label: l10n.gridColumns(config.gridCols),
            value: config.gridCols.toDouble(),
            min: kMinColumns.toDouble(),
            max: kMaxColumns.toDouble(),
            divisions: kMaxColumns - kMinColumns,
            onChanged: (v) => editor.setColumns(v.round()),
          ),
          kControlGap,
          Win98GroupBox(
            label: l10n.gridSampling,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Win98Radio<BlockSampling>(
                  value: BlockSampling.average,
                  groupValue: config.blockSampling,
                  label: l10n.samplingAverage,
                  onChanged: editor.setBlockSampling,
                ),
                Win98Radio<BlockSampling>(
                  value: BlockSampling.nearest,
                  groupValue: config.blockSampling,
                  label: l10n.samplingNearest,
                  onChanged: editor.setBlockSampling,
                ),
              ],
            ),
          ),
          kControlGap,
          LabeledSlider(
            label: l10n.gridGap(config.gridGapPx),
            value: config.gridGapPx.toDouble(),
            min: 0,
            max: 4,
            divisions: 4,
            onChanged: (v) => editor.setGridGap(v.round()),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Win98Button(
              onPressed: config.gridGapPx == 0
                  ? null
                  : () async {
                      final color = await showWin98ColorDialog(
                        context: context,
                        initial: Color(0xFF000000 | config.gridGapColor),
                        okLabel: l10n.ok,
                        cancelLabel: l10n.cancel,
                      );
                      if (color != null) editor.setGridGapColor(color.toARGB32());
                    },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: Bevel(
                      style: BevelStyle.status,
                      color: Color(0xFF000000 | config.gridGapColor),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(l10n.gridGapColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
