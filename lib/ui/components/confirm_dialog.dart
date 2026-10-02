import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'buttons.dart';
import 'surface.dart';

/// Asks before an action that can't be undone; true when confirmed.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: OverlayColors.scrim,
    builder: (context) {
      final c = context.colors;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(Space.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: DepthBox(
            style: context.depth.of(SurfaceDepth.floating),
            radius: Radii.panel,
            border: Border.all(color: c.borderStrong),
            padding: const EdgeInsets.all(Space.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.type.title.copyWith(color: c.foreground),
                ),
                const SizedBox(height: Space.s8),
                Text(
                  message,
                  style: context.type.body.copyWith(
                    color: c.foregroundSecondary,
                  ),
                ),
                const SizedBox(height: Space.s24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SButton.ghost(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const SizedBox(width: Space.s8),
                    destructive
                        ? SButton.destructive(
                            label: confirmLabel,
                            onPressed: () => Navigator.pop(context, true),
                          )
                        : SButton.primary(
                            label: confirmLabel,
                            onPressed: () => Navigator.pop(context, true),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}
