import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';

import '../services/image_codec.dart';

/// Displays an [RgbImage] without a PNG round-trip: it is wrapped in an
/// uncompressed BMP (cached per image) and drawn with nearest-neighbour
/// sampling so pixel blocks stay crisp: at exactly one image pixel per
/// screen pixel when it fits, otherwise scaled to fit.
class RgbImageView extends StatefulWidget {
  const RgbImageView({super.key, required this.image, this.semanticLabel});

  final RgbImage image;
  final String? semanticLabel;

  @override
  State<RgbImageView> createState() => _RgbImageViewState();
}

class _RgbImageViewState extends State<RgbImageView> {
  RgbImage? _encodedFor;
  late Uint8List _bytes;

  Uint8List get _bmp {
    if (!identical(_encodedFor, widget.image)) {
      _bytes = encodeBmp(widget.image);
      _encodedFor = widget.image;
    }
    return _bytes;
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.memory(
      _bmp,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
      semanticLabel: widget.semanticLabel,
    );
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // One image pixel per screen pixel when it fits (previews are
        // rendered to the canvas size for this): nearest-neighbour scaling
        // by a non-integer factor would make cells uneven.
        final w = widget.image.width / dpr;
        final h = widget.image.height / dpr;
        if (w <= constraints.maxWidth + 0.01 && h <= constraints.maxHeight + 0.01) {
          return SizedBox(width: w, height: h, child: image);
        }
        return AspectRatio(aspectRatio: widget.image.width / widget.image.height, child: image);
      },
    );
  }
}
