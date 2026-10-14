import 'package:flutter/material.dart';

import '../shared/layout/adaptive.dart';
import '../shared/theme/theme.dart';
import 'hero_frame.dart';
import 'skeleton.dart';

/// A hero's loading state: the same frame, with title, facts, synopsis
/// and an action shaped where the copy will land. Padding and type follow
/// the featured hero so the copy arrives over its own outline.
class HeroSkeleton extends StatelessWidget {
  const HeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final layout = LayoutSize(box.biggest);
      final type = context.type;
      final pad = layout.pick(
        compact: Space.s16,
        medium: Space.s24,
        expanded: Space.s48,
      );
      final banner = HeroFrame.stacked(context, box.maxWidth);
      return Semantics(
        label: 'Loading',
        excludeSemantics: true,
        child: HeroFrame(
          banner: banner,
          background: const Skeleton(radius: 0),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              pad,
              banner
                  ? pad
                  : HeroFrame.topPad(context, box.maxWidth, leading: false),
              pad,
              pad,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton.text(
                      widthFactor: .6,
                      style: layout.expanded
                          ? type.display
                          : layout.compact
                          ? type.headlineCompact
                          : type.headline,
                    ),
                    if (!banner) ...[
                      const SizedBox(height: Space.s12),
                      Skeleton.text(widthFactor: .4, style: type.bodySmall),
                      const SizedBox(height: Space.s12),
                      Skeleton.text(widthFactor: .95, style: type.bodySmall),
                      Skeleton.text(widthFactor: .7, style: type.bodySmall),
                    ],
                    SizedBox(height: banner ? Space.s16 : Space.s24),
                    Skeleton(
                      width: 128,
                      height: context.density.control,
                      radius: Radii.control,
                      tone: SkeletonTone.content,
                    ),
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
