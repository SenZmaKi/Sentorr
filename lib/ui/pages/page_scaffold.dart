import 'package:flutter/material.dart';

import '../components/content_column.dart';
import '../shared/layout/adaptive.dart';

/// Scrolling top-level page in the shared content column: responsive
/// gutters and the content width cap, with the scrollbar at the window
/// edge. Navigation already names the page, so it carries no headline.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.children,
    this.maxWidth = Breakpoints.contentMax,
  });

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final insets = ContentInsets(box.maxWidth, maxWidth: maxWidth);
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: insets.side,
            vertical: insets.gutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [...children],
          ),
        );
      },
    );
  }
}
