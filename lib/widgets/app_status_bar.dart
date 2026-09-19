import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/editor_model.dart';
import '../models/media_model.dart';
import '../services/filter_controller.dart';

/// The window's status bar: a status message, plus (once an image is
/// loaded) the grid size, color count and last render time.
class AppStatusBar extends StatelessWidget {
  const AppStatusBar({super.key, required this.l10n, required this.saving, required this.message});

  final AppLocalizations l10n;
  final bool saving;

  /// A transient status message (e.g. "Saved ..."), overriding the
  /// computed status when set.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final image = context.watch<MediaModel>();
    final filter = context.watch<FilterController>();
    final editor = context.watch<EditorModel>();
    final preview = image.preview;

    final String status;
    if (saving) {
      status = l10n.statusSaving;
    } else if (image.sampling) {
      status = l10n.statusSampling;
    } else if (image.loading || filter.busy) {
      status = l10n.statusWorking;
    } else if (filter.error != null) {
      status = l10n.errorFilter;
    } else {
      status =
          message ??
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
          Win98StatusPane(Text(l10n.statusColors(colorSet(result.grid.data).length)), flex: 0),
        if (ms != null) Win98StatusPane(Text(l10n.statusMs(ms)), flex: 0),
      ]);
    }
    return Win98StatusBar(panes: panes);
  }
}
