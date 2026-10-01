import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'buttons.dart';
import 'surface.dart';

/// Floating dialog: surfaceRaised, borderStrong, radius 16, padding 24.
Future<T?> showSDialog<T>(
  BuildContext context, {
  required String title,
  required String body,
  required List<Widget> Function(BuildContext) actions,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: OverlayColors.scrim,
    transitionDuration: Motion.panel,
    transitionBuilder: (context, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: child,
    ),
    pageBuilder: (context, _, _) {
      final c = context.colors;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            type: MaterialType.transparency,
            child: DepthBox(
              style: context.depth.of(SurfaceDepth.floating),
              radius: Radii.panel,
              border: Border.all(color: c.borderStrong),
              padding: const EdgeInsets.all(Space.s24),
              child: Semantics(
                scopesRoute: true,
                explicitChildNodes: true,
                namesRoute: true,
                label: title,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.type.title.copyWith(color: c.foreground)),
                    const SizedBox(height: Space.s8),
                    Text(body, style: context.type.body.copyWith(color: c.foregroundSecondary)),
                    const SizedBox(height: Space.s24),
                    Row(mainAxisAlignment: MainAxisAlignment.end, spacing: Space.s8, children: actions(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Floating toast: radius 12, padding 16, announced politely.
void showSToast(BuildContext context, {required String message, IconData icon = Icons.check_circle_outline}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      final c = context.colors;
      return Positioned(
        right: Space.s24,
        bottom: Space.s24,
        child: Semantics(
          liveRegion: true,
          child: Material(
            type: MaterialType.transparency,
            child: DepthBox(
              style: context.depth.of(SurfaceDepth.floating),
              radius: Radii.card,
              border: Border.all(color: c.borderStrong),
              padding: const EdgeInsets.all(Space.s16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: IconSizes.control, color: c.success),
                  const SizedBox(width: Space.s12),
                  Text(message, style: context.type.bodySmall.copyWith(color: c.foreground)),
                  const SizedBox(width: Space.s16),
                  SIconButton(icon: Icons.close, tooltip: 'Dismiss', onPressed: entry.remove),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 4), () {
    if (entry.mounted) entry.remove();
  });
}
