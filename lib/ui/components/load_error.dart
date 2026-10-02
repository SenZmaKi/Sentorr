import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'buttons.dart';

/// Plain-language failure with the next action, for a region that could
/// not load. Color is never the only cue: icon and text carry the state.
class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.s12,
      runSpacing: Space.s8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: IconSizes.control, color: c.error),
            const SizedBox(width: Space.s8),
            Flexible(
              child: Text(
                message,
                style: context.type.bodySmall.copyWith(color: c.foreground),
              ),
            ),
          ],
        ),
        SButton(label: 'Try again', icon: Icons.refresh, onPressed: onRetry),
      ],
    );
  }
}
