import 'package:flutter/widgets.dart';
import 'package:win98_ui/win98_ui.dart';

import '../l10n/generated/app_localizations.dart';

/// Shown in the preview area before an image is loaded: a little
/// dialog-style panel with Gallery / Camera buttons.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.onGallery, required this.onCamera});

  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Win98Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Bevel(
            style: BevelStyle.window,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Win98MessageIcon(Win98MessageIconType.info),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l10n.emptyTitle, style: theme.boldTextStyle)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(l10n.emptyBody),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Win98Button(
                      isDefault: true,
                      onPressed: onGallery,
                      child: Text(l10n.emptyGallery),
                    ),
                    Win98Button(onPressed: onCamera, child: Text(l10n.emptyCamera)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
