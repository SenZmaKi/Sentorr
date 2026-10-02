import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';

/// Scrolling top-level page with responsive gutters and the shared content
/// width cap. Navigation already names the page, so it carries no headline.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.children, this.maxWidth = 1400});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final gutter = box.maxWidth < 600 ? Space.s16 : Space.s24;
        return SingleChildScrollView(
          padding: EdgeInsets.all(gutter),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [...children],
              ),
            ),
          ),
        );
      },
    );
  }
}
