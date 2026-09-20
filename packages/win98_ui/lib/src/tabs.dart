import 'package:flutter/widgets.dart';

import 'bevel.dart';
import 'theme.dart';

/// A page of a [Win98TabView].
class Win98Tab {
  const Win98Tab({required this.label, required this.builder});
  final String label;
  final WidgetBuilder builder;
}

/// Caches label text-layout widths per `(label, style, scaler)`, so
/// [Win98TabView] doesn't re-run text shaping for unchanged labels on every
/// rebuild — previously the dominant per-rebuild cost of a tab strip with
/// several labels, since it ran on every rebuild, not just when the tab
/// selection or available width actually changed.
class TabLabelWidthCache {
  final _widths = <(String, TextStyle, TextScaler), double>{};

  /// Number of distinct `(label, style, scaler)` keys cached so far (tests
  /// only, to assert repeat lookups don't grow the cache).
  int get widthsForTest => _widths.length;

  double widthOf(String label, TextStyle style, TextScaler scaler) {
    final key = (label, style, scaler);
    final cached = _widths[key];
    if (cached != null) return cached;
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return _widths[key] = width;
  }
}

/// Property-sheet style tabs over a raised panel. The selected tab is raised
/// and merges into the panel.
///
/// When the tabs don't fit in one line they wrap into several rows, as in
/// Windows 98: every row is stretched to the full width, and the row holding
/// the selected tab moves down next to the panel.
class Win98TabView extends StatefulWidget {
  const Win98TabView({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.onChanged,
    this.panelPadding = const EdgeInsets.all(8),
  });

  final List<Win98Tab> tabs;
  final int initialIndex;
  final ValueChanged<int>? onChanged;
  final EdgeInsetsGeometry panelPadding;

  @override
  State<Win98TabView> createState() => _Win98TabViewState();
}

class _Win98TabViewState extends State<Win98TabView> {
  late int _index = widget.initialIndex.clamp(0, widget.tabs.length - 1);

  static const _labelPadding = 20.0;

  final _widthCache = TabLabelWidthCache();

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    widget.onChanged?.call(i);
  }

  /// Greedily pack tab indices into rows no wider than `maxWidth`.
  List<List<int>> _rows(Win98ThemeData theme, double maxWidth, TextScaler scaler) {
    final rows = <List<int>>[[]];
    var used = 0.0;
    for (var i = 0; i < widget.tabs.length; i++) {
      final w = _widthCache.widthOf(widget.tabs[i].label, theme.textStyle, scaler) + _labelPadding;
      if (rows.last.isNotEmpty && used + w > maxWidth) {
        rows.add([]);
        used = 0;
      }
      rows.last.add(i);
      used += w;
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    final tabHeight = theme.controlHeight;
    final index = _index.clamp(0, widget.tabs.length - 1);
    final scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth - 4 : double.infinity;
        var rows = _rows(theme, width, scaler);
        final multiRow = rows.length > 1;
        // The selected tab's row sits next to the panel.
        final selectedRow = rows.indexWhere((r) => r.contains(index));
        final selected = rows.removeAt(selectedRow);
        rows = [...rows, selected];
        final stripHeight = tabHeight * rows.length;

        Widget tabRow(List<int> row, bool last) {
          final tabs = [
            for (final i in row)
              _TabButton(
                label: widget.tabs[i].label,
                selected: last && i == index,
                height: tabHeight,
                onTap: () => _select(i),
              ),
          ];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: multiRow ? [for (final t in tabs) Expanded(child: t)] : tabs,
          );
        }

        return Stack(
          fit: StackFit.passthrough,
          children: [
            Padding(
              padding: EdgeInsets.only(top: stripHeight),
              child: Bevel(
                style: BevelStyle.window,
                padding: widget.panelPadding,
                child: KeyedSubtree(
                  key: ValueKey(index),
                  child: widget.tabs[index].builder(context),
                ),
              ),
            ),
            for (var r = 0; r < rows.length; r++)
              Positioned(
                top: r * tabHeight,
                left: 2,
                right: 2,
                height: tabHeight + 2,
                child: tabRow(rows[r], r == rows.length - 1),
              ),
          ],
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // Unselected tabs sit 2px lower and don't reach into the panel.
          padding: EdgeInsets.only(top: selected ? 0 : 2),
          child: CustomPaint(
            painter: _TabPainter(theme: theme, selected: selected),
            child: SizedBox(
              height: selected ? height + 2 : height - 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
                child: Center(
                  widthFactor: 1,
                  child: Text(label, maxLines: 1, overflow: TextOverflow.clip, softWrap: false),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabPainter extends CustomPainter {
  _TabPainter({required this.theme, required this.selected});
  final Win98ThemeData theme;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = theme.face);
    Paint p(Color c) => Paint()..color = c;
    // Left and top highlights with a clipped corner, right-hand shadows.
    canvas.drawRect(Rect.fromLTWH(0, 2, 1, h - 2), p(theme.highlight));
    canvas.drawRect(Rect.fromLTWH(1, 1, 1, 1), p(theme.highlight));
    canvas.drawRect(Rect.fromLTWH(2, 0, w - 4, 1), p(theme.highlight));
    canvas.drawRect(Rect.fromLTWH(1, 2, 1, h - 2), p(theme.light));
    canvas.drawRect(Rect.fromLTWH(2, 1, w - 4, 1), p(theme.light));
    canvas.drawRect(Rect.fromLTWH(w - 2, 1, 1, 1), p(theme.darkShadow));
    canvas.drawRect(Rect.fromLTWH(w - 1, 2, 1, h - 2), p(theme.darkShadow));
    canvas.drawRect(Rect.fromLTWH(w - 2, 2, 1, h - 2), p(theme.shadow));
  }

  @override
  bool shouldRepaint(_TabPainter old) => old.selected != selected || old.theme != theme;
}
