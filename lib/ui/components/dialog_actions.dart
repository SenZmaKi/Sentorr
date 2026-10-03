import 'package:flutter/widgets.dart';

import '../shared/theme/theme.dart';

/// Trailing dialog and panel actions: one end-aligned row while they fit,
/// stacked full-width (primary first) when a narrow window or large text
/// would overflow it. Pass actions in reading order, primary last.
class DialogActions extends StatelessWidget {
  const DialogActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => OverflowBar(
    alignment: MainAxisAlignment.end,
    spacing: Space.s8,
    overflowSpacing: Space.s8,
    overflowAlignment: OverflowBarAlignment.end,
    overflowDirection: VerticalDirection.up,
    children: children,
  );
}
