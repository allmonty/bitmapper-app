import 'dart:ui' as ui;

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';

/// Displays an [RgbImage] by uploading its pixels straight to a GPU image
/// (`decodeImageFromPixels`), with no image file format in between: the
/// image has exactly the size given, and is drawn with nearest-neighbour
/// sampling so pixel blocks stay crisp: at exactly one image pixel per
/// screen pixel when it fits, otherwise scaled to fit.
///
/// (Wrapping the pixels in a BMP and decoding that with `Image.memory`
/// rendered partly smeared toward the right and bottom on some Android
/// devices.)
class RgbImageView extends StatefulWidget {
  const RgbImageView({super.key, required this.image, this.semanticLabel});

  final RgbImage image;
  final String? semanticLabel;

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
    // Lay out for the latest picture even before its upload finishes.
    final shown = widget.image;
    final picture = RawImage(image: _uploaded, fit: BoxFit.fill, filterQuality: FilterQuality.none);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // One image pixel per screen pixel when it fits (previews are
          // rendered to the canvas size for this): nearest-neighbour scaling
          // by a non-integer factor would make cells uneven.
          final w = shown.width / dpr;
          final h = shown.height / dpr;
          // Centered, so a parent that forces a size can't stretch it.
          if (w <= constraints.maxWidth + 0.01 && h <= constraints.maxHeight + 0.01) {
            return Center(
              child: SizedBox(width: w, height: h, child: picture),
            );
          }
          return Center(
            child: AspectRatio(aspectRatio: shown.width / shown.height, child: picture),
          );
        },
      ),
    );
  }
}
