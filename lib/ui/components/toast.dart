import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'buttons.dart';
import 'surface.dart';

enum ToastTone { info, success, warning, error }

/// A transient floating notice: status icon, title, an optional message
/// and actions, and a dismiss control. Placement and lifetime belong to the
/// host showing it, e.g. [ErrorToasts].
class Toast extends StatelessWidget {
  const Toast({
    super.key,
    required this.tone,
    required this.title,
    this.message,
    this.actions = const [],
    required this.onDismiss,
  });

  static const maxWidth = 400.0;

  final ToastTone tone;
  final String title;
  final String? message;
  final List<Widget> actions;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color) = switch (tone) {
      ToastTone.info => (Icons.info_outline_rounded, c.info),
      ToastTone.success => (Icons.check_circle_outline_rounded, c.success),
      ToastTone.warning => (Icons.warning_amber_rounded, c.warning),
      ToastTone.error => (Icons.error_outline_rounded, c.error),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: DepthBox(
          style: context.depth.of(SurfaceDepth.floating),
          radius: Radii.card,
          border: Border.all(color: c.borderStrong),
          padding: const EdgeInsets.fromLTRB(
            Space.s16,
            Space.s16,
            Space.s8,
            Space.s12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: Space.s2),
                child: Icon(icon, size: IconSizes.control, color: color),
              ),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: Space.s2),
                      child: Text(
                        title,
                        style: context.type.label.copyWith(color: c.foreground),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: Space.s4),
                      Text(
                        message!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.bodySmall.copyWith(
                          color: c.foregroundSecondary,
                        ),
                      ),
                    ],
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: Space.s8),
                      // Ghost actions sit flush with the text above them.
                      Transform.translate(
                        offset: const Offset(-Space.s16, 0),
                        child: Wrap(spacing: Space.s8, children: actions),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Space.s4),
              SIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Dismiss',
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
