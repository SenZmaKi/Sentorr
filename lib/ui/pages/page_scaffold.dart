import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';

/// Scrolling top-level page with a headline, responsive gutters and the
/// shared content width cap.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.maxWidth = 1400,
  });

  final String title;
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
                children: [
                  Text(
                    title,
                    style: context.type.headline.copyWith(
                      color: context.colors.foreground,
                    ),
                  ),
                  const SizedBox(height: Space.s24),
                  ...children,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
