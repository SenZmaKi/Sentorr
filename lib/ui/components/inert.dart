import 'package:flutter/widgets.dart';

/// Content covered by a layer above it: still painted, but takes no
/// pointer, focus or semantics, and its tickers pause.
class Inert extends StatelessWidget {
  const Inert({super.key, required this.inert, required this.child});

  final bool inert;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: inert,
    child: ExcludeFocus(
      excluding: inert,
      child: ExcludeSemantics(
        excluding: inert,
        child: TickerMode(enabled: !inert, child: child),
      ),
    ),
  );
}
