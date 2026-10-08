import 'package:flutter/material.dart';

import '../shared/layout/adaptive.dart';
import '../shared/theme/theme.dart';
import 'surface.dart';

/// Row heading: a raised icon tile names the row's purpose at a glance,
/// then title, an optional explanation, and an optional count.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleLink,
    this.count,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Independent navigation when the subtitle names another title.
  final Widget? subtitleLink;

  /// Trailing tally, e.g. "5 new".
  final String? count;

  /// Trailing control for the row, e.g. a toggle.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // A phone's tile steps down so the heading, not the icon, leads.
    final compact = context.screen.compact;
    final tile = compact ? Space.s32 : ControlHeights.standard;
    return Row(
      children: [
        DepthBox(
          style: context.depth.of(SurfaceDepth.raised),
          radius: Radii.control,
          width: tile,
          height: tile,
          child: Icon(
            icon,
            size: compact ? IconSizes.metadata : IconSizes.control,
            color: c.foreground,
          ),
        ),
        const SizedBox(width: Space.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.subtitle.copyWith(
                        color: c.foreground,
                      ),
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: Space.s8),
                    // Like badges, a count shortens rather than overflows
                    // a header squeezed by its action.
                    Flexible(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.surfaceInset,
                          borderRadius: BorderRadius.circular(Radii.chip),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.s8,
                            vertical: Space.s2,
                          ),
                          child: Text(
                            count!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.technical.copyWith(
                              color: c.foregroundSecondary,
                              fontSize: 12,
                              height: 16 / 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitleLink != null)
                subtitleLink!
              else if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.bodySmall.copyWith(
                    color: c.foregroundMuted,
                  ),
                ),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: Space.s12), action!],
      ],
    );
  }
}
