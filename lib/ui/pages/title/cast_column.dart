import 'package:flutter/material.dart';

import '../../../imdb/models.dart';
import '../../components/app_image.dart';
import '../../components/buttons.dart';
import '../../components/section_header.dart';
import '../../components/surface.dart';
import '../../components/title_artwork.dart';
import '../../shared/theme/theme.dart';

/// The cast as a vertical list, for the side column beside a series'
/// episodes on large layouts. The first few show; the rest on request.
class CastColumn extends StatefulWidget {
  const CastColumn({super.key, required this.cast});

  /// Width of the side column on the title page.
  static const double width = 320;

  final List<ImdbCredit> cast;

  @override
  State<CastColumn> createState() => _CastColumnState();
}

class _CastColumnState extends State<CastColumn> {
  static const _shown = 10;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final cast = widget.cast;
    final shown = _all ? cast : cast.take(_shown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.people_alt_outlined,
          title: 'Cast',
          count: '${cast.length}',
        ),
        const SizedBox(height: Space.s16),
        for (final c in shown) _CastRow(c),
        if (cast.length > _shown)
          Align(
            alignment: Alignment.centerLeft,
            child: SButton.ghost(
              label: _all ? 'Show fewer' : 'Show all',
              icon: _all
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              onPressed: () => setState(() => _all = !_all),
            ),
          ),
      ],
    );
  }
}

/// Headshot beside the name and character. Informational, not a target.
class _CastRow extends StatelessWidget {
  const _CastRow(this.credit);

  static const _avatar = 48.0;

  final ImdbCredit credit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final role = credit.characters.isEmpty
        ? null
        : credit.characters.join(' / ');
    return Semantics(
      label: [credit.person.name, ?role].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s8),
        child: Row(
          children: [
            DepthBox(
              style: context.depth.of(SurfaceDepth.raised),
              radius: Radii.full,
              width: _avatar,
              height: _avatar,
              child: ClipOval(
                child: credit.person.image == null
                    ? const ArtworkPlaceholder(
                        icon: Icons.person_outline_rounded,
                      )
                    : TitleArtwork(
                        image: credit.person.image,
                        alignment: const Alignment(0, -0.6),
                      ),
              ),
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    credit.person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.label.copyWith(
                      color: c.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (role != null)
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.caption.copyWith(
                        color: c.foregroundMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
