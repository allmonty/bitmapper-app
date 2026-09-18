import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/media_model.dart';

/// "Frame i / n" and a slider to pick the animation frame to preview.
class FrameScrubber extends StatelessWidget {
  const FrameScrubber({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = context.watch<MediaModel>();
    final count = media.frameCount;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(l10n.frameLabel(media.currentFrame + 1, count), maxLines: 1),
          ),
          Expanded(
            child: Win98Slider(
              value: media.currentFrame.toDouble(),
              max: (count - 1).toDouble(),
              divisions: count - 1,
              showTicks: count <= 40,
              semanticLabel: l10n.frameLabel(media.currentFrame + 1, count),
              onChanged: (v) => media.setFrame(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}
