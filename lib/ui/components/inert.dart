import 'package:flutter/widgets.dart';

/// Content covered by a layer above it: still painted, but takes no
/// pointer, focus or semantics, and its tickers pause. Opaque covering layers
/// may also suppress painting while retaining the child's state and layout.
class Inert extends StatelessWidget {
  const Inert({
    super.key,
    required this.inert,
    this.suppressPainting = false,
    required this.child,
  });

  final bool inert;
  final bool suppressPainting;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: inert,
    child: ExcludeFocus(
      excluding: inert,
      child: ExcludeSemantics(
        excluding: inert,
        child: TickerMode(
          enabled: !inert,
          child: Offstage(offstage: inert && suppressPainting, child: child),
        ),
      ),
    ),
  );
}
