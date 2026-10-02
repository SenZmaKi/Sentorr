import 'package:flutter/material.dart';

import '../../../imdb/models.dart';
import '../../shared/theme/theme.dart';
import '../app_image.dart';
import '../surface.dart';
import '../title_artwork.dart';
import 'card_parts.dart';

/// A cast member: a round headshot, name, then who they play, centred.
/// Kept small so the row reads as credits, not as more titles to browse.
/// Informational; there are no person pages to open.
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.name,
    required this.avatar,
    this.image,
    this.role,
  });

  final String name;

  /// Headshot diameter; the tile is wider so names have room.
  final double avatar;
  final ImdbImage? image;

  /// Character played, or a crew role.
  final String? role;

  static double textHeight(CardLines l) =>
      Space.s8 + l.small + Space.s2 + l.caption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: [name, ?role].join(', '),
      excludeSemantics: true,
      child: Column(
        children: [
          DepthBox(
            style: context.depth.of(SurfaceDepth.raised),
            radius: Radii.full,
            width: avatar,
            height: avatar,
            child: ClipOval(
              child: image == null
                  ? const ArtworkPlaceholder(icon: Icons.person_outline_rounded)
                  : TitleArtwork(
                      image: image,
                      // Headshots frame the face in the upper third.
                      alignment: const Alignment(0, -0.6),
                    ),
            ),
          ),
          const SizedBox(height: Space.s8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.type.label.copyWith(
              color: c.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Space.s2),
          Text(
            role ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.type.caption.copyWith(color: c.foregroundMuted),
          ),
        ],
      ),
    );
  }
}
