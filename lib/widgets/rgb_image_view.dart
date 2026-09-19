import 'dart:ui' as ui;

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';

/// Displays an [RgbImage] (a photo) fitted to the available space, by
/// uploading its pixels straight to a GPU image (`decodeImageFromPixels`)
/// with no image file format in between. Filtered pixel art is shown by
/// `PixelGridView` instead, which paints cells without any image.
class RgbImageView extends StatefulWidget {
  const RgbImageView({
    super.key,
    required this.image,
    this.semanticLabel,
    this.filterQuality = FilterQuality.medium,
  });

  final RgbImage image;
  final String? semanticLabel;
  final FilterQuality filterQuality;

  @override
  State<RgbImageView> createState() => _RgbImageViewState();
}

class _RgbImageViewState extends State<RgbImageView> {
  /// The latest uploaded picture. It stays on screen while a newer one
  /// uploads, so nothing flickers.
  ui.Image? _uploaded;

  /// The picture being uploaded; older uploads that finish late are dropped.
  RgbImage? _pending;

  @override
  void initState() {
    super.initState();
    _upload();
  }

  @override
  void didUpdateWidget(RgbImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.image, widget.image)) _upload();
  }

  void _upload() {
    final source = widget.image;
    _pending = source;
    ui.decodeImageFromPixels(
      source.toRgba(),
      source.width,
      source.height,
      ui.PixelFormat.rgba8888,
      (image) {
        if (!mounted || !identical(_pending, source)) {
          image.dispose(); // superseded by a newer picture
          return;
        }
        setState(() {
          _uploaded?.dispose();
          _uploaded = image;
        });
      },
    );
  }

  @override
  void dispose() {
    _pending = null;
    _uploaded?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: Center(
        child: AspectRatio(
          aspectRatio: widget.image.width / widget.image.height,
          child: RawImage(image: _uploaded, fit: BoxFit.fill, filterQuality: widget.filterQuality),
        ),
      ),
    );
  }
}
