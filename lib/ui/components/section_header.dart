import 'package:flutter/material.dart';

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
    this.count,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Trailing tally, e.g. "5 new".
  final String? count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        DepthBox(
          style: context.depth.of(SurfaceDepth.raised),
          radius: Radii.control,
          width: ControlHeights.standard,
          height: ControlHeights.standard,
          child: Icon(icon, size: IconSizes.control, color: c.foreground),
        ),
        const SizedBox(width: Space.s12),
        Flexible(
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
                    DecoratedBox(
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
                          style: context.type.technical.copyWith(
                            color: c.foregroundSecondary,
                            fontSize: 12,
                            height: 16 / 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitle != null)
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
      ],
    );
  }
}
