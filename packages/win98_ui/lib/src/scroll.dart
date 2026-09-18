import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'bevel.dart';
import 'button.dart';
import 'glyphs.dart';
import 'theme.dart';

/// A vertically scrolling area with a Win98 scrollbar (arrow buttons,
/// dithered track, draggable raised thumb). The bar is only shown when the
/// content overflows.
class Win98ScrollView extends StatefulWidget {
  const Win98ScrollView({super.key, required this.child, this.controller, this.padding});

  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  @override
  State<Win98ScrollView> createState() => _Win98ScrollViewState();
}

class _Win98ScrollViewState extends State<Win98ScrollView> {
  ScrollController? _own;
  ScrollController get _controller => widget.controller ?? (_own ??= ScrollController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: const _NoGlowBehavior(),
            child: SingleChildScrollView(
              controller: _controller,
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
        Win98Scrollbar(controller: _controller),
      ],
    );
  }
}

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

/// A vertical scrollbar driving `controller`. Place it next to the
/// scrollable that uses the same controller.
class Win98Scrollbar extends StatefulWidget {
  const Win98Scrollbar({super.key, required this.controller, this.step = 40});

  final ScrollController controller;

  /// Pixels scrolled per arrow tap.
  final double step;

  @override
  State<Win98Scrollbar> createState() => _Win98ScrollbarState();
}

class _Win98ScrollbarState extends State<Win98Scrollbar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    // Metrics only exist after the scrollable's first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => _changed());
  }

  @override
  void didUpdateWidget(Win98Scrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _changed());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  ScrollPosition? get _position =>
      widget.controller.hasClients && widget.controller.positions.length == 1
      ? widget.controller.position
      : null;

  void _scrollBy(double delta) {
    final p = _position;
    if (p == null) return;
    p.jumpTo((p.pixels + delta).clamp(p.minScrollExtent, p.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    final p = _position;
    if (p == null || !p.hasContentDimensions || p.maxScrollExtent <= 0) {
      return const SizedBox.shrink();
    }
    final size = theme.scrollbarSize;
    Widget arrow(List<String> glyph, double delta, String label) => Win98Button(
      onPressed: () => _scrollBy(delta),
      minWidth: size,
      minHeight: size,
      padding: EdgeInsets.zero,
      semanticLabel: label,
      child: PixelGlyph(glyph, color: theme.text, pixelSize: 1.5),
    );

    return SizedBox(
      width: size,
      child: Column(
        children: [
          arrow(Win98Glyphs.arrowUp, -widget.step, 'Scroll up'),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final track = constraints.maxHeight;
                final content = p.maxScrollExtent + p.viewportDimension;
                final thumb = math
                    .max(size, track * p.viewportDimension / content)
                    .clamp(0.0, track);
                final range = track - thumb;
                final offset = p.maxScrollExtent == 0
                    ? 0.0
                    : range * (p.pixels / p.maxScrollExtent);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Clicking the track pages up/down, as in Win98.
                  onTapDown: (d) => _scrollBy(
                    d.localPosition.dy < offset ? -p.viewportDimension : p.viewportDimension,
                  ),
                  child: CustomPaint(
                    painter: _TrackPainter(theme),
                    child: Stack(
                      children: [
                        Positioned(
                          top: offset,
                          left: 0,
                          right: 0,
                          height: thumb,
                          child: GestureDetector(
                            onVerticalDragUpdate: (d) {
                              if (range <= 0) return;
                              _scrollBy(d.delta.dy / range * p.maxScrollExtent);
                            },
                            child: const Bevel(style: BevelStyle.raised),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          arrow(Win98Glyphs.arrowDown, widget.step, 'Scroll down'),
        ],
      ),
    );
  }
}

/// The checkerboard of face and highlight pixels behind the thumb.
class _TrackPainter extends CustomPainter {
  _TrackPainter(this.theme);
  final Win98ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = theme.face);
    final dots = Paint()..color = theme.highlight;
    for (var y = 0; y < size.height; y++) {
      for (var x = y.isEven ? 0 : 1; x < size.width; x += 2) {
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), dots);
      }
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.theme != theme;
}
