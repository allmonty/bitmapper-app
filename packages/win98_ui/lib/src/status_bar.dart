import 'package:flutter/widgets.dart';

import 'bevel.dart';

/// One pane of a [Win98StatusBar].
class Win98StatusPane {
  const Win98StatusPane(this.child, {this.flex = 1});
  final Widget child;

  /// Relative width; `0` sizes the pane to its content (capped so the
  /// flexible panes keep some room, ellipsizing if needed).
  final int flex;
}

/// A row of shallow sunken panes along the bottom of a window.
class Win98StatusBar extends StatelessWidget {
  const Win98StatusBar({super.key, required this.panes});

  final List<Win98StatusPane> panes;

  /// Width always left for the flexible panes.
  static const _flexibleReserve = 60.0;

  @override
  Widget build(BuildContext context) {
    Widget pane(Win98StatusPane p) => Bevel(
      style: BevelStyle.status,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: DefaultTextStyle.merge(
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        child: p.child,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fixed = panes.where((p) => p.flex == 0).length;
          final gaps = 2.0 * (panes.length - 1);
          final cap = fixed == 0
              ? double.infinity
              : ((constraints.maxWidth - gaps - _flexibleReserve) / fixed).clamp(
                  0.0,
                  double.infinity,
                );
          return Row(
            children: [
              for (var i = 0; i < panes.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                if (panes[i].flex == 0)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cap),
                    child: pane(panes[i]),
                  )
                else
                  Expanded(flex: panes[i].flex, child: pane(panes[i])),
              ],
            ],
          );
        },
      ),
    );
  }
}
