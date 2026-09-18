import 'dart:typed_data';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/widgets.dart';

import '../services/image_codec.dart';

/// Displays an [RgbImage] without a PNG round-trip: it is wrapped in an
/// uncompressed BMP (cached per image) and drawn with nearest-neighbour
/// sampling so pixel blocks stay crisp.
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
    return AspectRatio(
      aspectRatio: widget.image.width / widget.image.height,
      child: Image.memory(
        _bmp,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        gaplessPlayback: true,
        semanticLabel: widget.semanticLabel,
      ),
    );
  }
}
