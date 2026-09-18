import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/media_model.dart';
import '../services/filter_controller.dart';
import 'empty_state.dart';
import 'frame_scrubber.dart';
import 'rgb_image_view.dart';

/// The sunken canvas: filtered preview with pinch-zoom, and hold-to-compare
/// against the original.
class PreviewPane extends StatefulWidget {
  const PreviewPane({super.key, required this.onGallery, required this.onCamera});

  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  State<PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends State<PreviewPane> {
  bool _showOriginal = false;

  void _setOriginal(bool value) {
    if (_showOriginal != value) setState(() => _showOriginal = value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Win98Theme.of(context);
    final image = context.watch<MediaModel>();
    final filter = context.watch<FilterController>();
    final preview = image.preview;

    Widget content;
    if (preview == null) {
      content = image.loading
          ? const Center(child: SizedBox(width: 200, child: Win98ProgressBar()))
          : EmptyState(onGallery: widget.onGallery, onCamera: widget.onCamera);
    } else {
      final output = filter.result?.output;
      final showOriginal = _showOriginal || output == null;
      content = Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onLongPressStart: (_) => _setOriginal(true),
            onLongPressEnd: (_) => _setOriginal(false),
            onLongPressCancel: () => _setOriginal(false),
            child: InteractiveViewer(
              maxScale: 8,
              child: Center(
                child: RgbImageView(
                  key: const Key('preview-image'),
                  image: showOriginal ? preview : output,
                  semanticLabel: image.name,
                ),
              ),
            ),
          ),
          Positioned(
            left: 4,
            bottom: 4,
            child: IgnorePointer(
              child: ColoredBox(
                color: theme.tooltip,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  child: Text(
                    _showOriginal ? '◀ ${l10n.holdToCompare}' : l10n.holdToCompare,
                    style: theme.textStyle.copyWith(fontSize: theme.fontSize - 3),
                  ),
                ),
              ),
            ),
          ),
          if (filter.busy)
            const Positioned(right: 4, bottom: 4, width: 90, child: Win98ProgressBar(height: 16)),
        ],
      );
    }

    final canvas = Bevel(
      style: BevelStyle.field,
      color: theme.shadow,
      child: ClipRect(child: content),
    );
    if (!image.isAnimation) return canvas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: canvas),
        const FrameScrubber(),
      ],
    );
  }
}
