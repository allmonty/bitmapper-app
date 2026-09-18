import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Anchors a popup (menu, drop-down list) to a widget using an
/// [OverlayPortal]. The popup opens below the anchor, or above it when there
/// is more room there, and is kept on screen. Tapping outside closes it.
class Win98PopupAnchor extends StatefulWidget {
  const Win98PopupAnchor({
    super.key,
    required this.builder,
    required this.popupBuilder,
    this.matchWidth = false,
    this.onClosed,
  });

  /// Builds the anchor; call `toggle` to open or close the popup.
  final Widget Function(BuildContext context, bool isOpen, VoidCallback toggle) builder;

  /// Builds the popup; call `close` to dismiss it.
  final Widget Function(BuildContext context, VoidCallback close) popupBuilder;

  /// Make the popup at least as wide as the anchor (drop-down lists).
  final bool matchWidth;
  final VoidCallback? onClosed;

  @override
  State<Win98PopupAnchor> createState() => _Win98PopupAnchorState();
}

class _Win98PopupAnchorState extends State<Win98PopupAnchor> {
  final _controller = OverlayPortalController();
  Rect _anchor = Rect.zero;

  void _toggle() {
    if (_controller.isShowing) {
      _close();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    _anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    setState(_controller.show);
  }

  void _close() {
    if (!_controller.isShowing) return;
    setState(_controller.hide);
    widget.onClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (overlayContext) {
        final padding = MediaQuery.maybePaddingOf(overlayContext) ?? EdgeInsets.zero;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _close),
            ),
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _PopupLayout(
                  anchor: _anchor,
                  matchWidth: widget.matchWidth,
                  safeArea: padding,
                ),
                child: widget.popupBuilder(overlayContext, _close),
              ),
            ),
          ],
        );
      },
      child: widget.builder(context, _controller.isShowing, _toggle),
    );
  }
}

class _PopupLayout extends SingleChildLayoutDelegate {
  _PopupLayout({required this.anchor, required this.matchWidth, required this.safeArea});

  final Rect anchor;
  final bool matchWidth;
  final EdgeInsets safeArea;

  static const _margin = 4.0;

  double _below(Size size) => size.height - safeArea.bottom - _margin - anchor.bottom;
  double _above(Size size) => anchor.top - safeArea.top - _margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final maxWidth = math.max(0.0, size.width - _margin * 2);
    final maxHeight = math.max(0.0, math.max(_below(size), _above(size)));
    return BoxConstraints(
      minWidth: matchWidth ? math.min(anchor.width, maxWidth) : 0,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final fitsBelow = childSize.height <= _below(size);
    final y = fitsBelow || _below(size) >= _above(size)
        ? anchor.bottom
        : anchor.top - childSize.height;
    final x = anchor.left
        .clamp(_margin, math.max(_margin, size.width - _margin - childSize.width))
        .toDouble();
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopupLayout old) =>
      old.anchor != anchor || old.matchWidth != matchWidth || old.safeArea != safeArea;
}
