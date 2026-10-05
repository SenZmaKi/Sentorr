import 'package:flutter/material.dart';

import '../../../imdb/models.dart';
import '../../components/artwork_frame.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/hero_frame.dart';
import '../../components/motion.dart';
import '../../components/title_artwork.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import '../../shared/title_icons.dart';
import '../../shared/layout/adaptive.dart';

/// The title's backdrop carrying everything a viewer decides on: Back, the
/// poster with its rating, name, facts, genres, synopsis, key people and
/// actions. Renders from the catalog summary at once; [details] fill in
/// the certificate, counts, people and backdrop as they arrive.
class TitleHero extends StatelessWidget {
  const TitleHero({
    super.key,
    required this.title,
    required this.onBack,
    this.details,
    this.onPlay,
    this.playLabel = 'Play',
    this.onEpisodes,
    this.actions = const [],
  });

  final ImdbTitle title;
  final ImdbTitleDetails? details;
  final VoidCallback onBack;
  final VoidCallback? onPlay;

  /// e.g. "Resume" or "Continue S1 E4" for a title already started.
  final String playLabel;

  /// Series only: jumps to the episode list.
  final VoidCallback? onEpisodes;

  /// Further actions after Play and Episodes, e.g. Download or Follow.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final layout = LayoutSize(box.biggest);
        final wide = layout.expanded;
        final pad = layout.pick(
          compact: Space.s16,
          medium: Space.s24,
          expanded: Space.s48,
        );
        // Two columns from medium: the poster (carrying the rating) beside
        // the copy. Short windows give the height to the copy instead.
        final posterWidth = context.screen.short
            ? null
            : layout.pick<double?>(compact: null, medium: 160, expanded: 200);
        return HeroFrame(
          background: Stack(
            fit: StackFit.expand,
            children: [
              TitleBackdrop(title: title, waitForBackdrop: true),
              const ArtworkFade(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.15, 1],
              ),
              if (wide)
                const ArtworkFade(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  stops: [0.3, 1],
                ),
            ],
          ),
          leading: ImageOverlayContext(
            child: OverlayIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: onBack,
            ),
          ),
          child: ImageOverlayContext(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                pad,
                HeroFrame.topPad(context, box.maxWidth),
                pad,
                pad,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (posterWidth != null) ...[
                    Reveal(child: _Poster(title, width: posterWidth)),
                    SizedBox(width: wide ? Space.s32 : Space.s24),
                  ],
                  Expanded(
                    child: _Copy(
                      hero: this,
                      wide: wide,
                      compact: layout.compact,
                      poster: posterWidth != null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster(this.title, {required this.width});

  final ImdbTitle title;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = title;
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: ArtworkFrame(
          active: false,
          artwork: TitleArtwork(image: t.poster),
          decorations: [
            if (t.rating != null)
              Positioned(
                right: Space.s8,
                top: Space.s8,
                child: Semantics(
                  label: 'Rated ${t.rating!.toStringAsFixed(1)} out of 10',
                  excludeSemantics: true,
                  child: OverlayBadge(
                    t.rating!.toStringAsFixed(1),
                    icon: Icons.star_rounded,
                    technical: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Copy extends StatelessWidget {
  const _Copy({
    required this.hero,
    required this.wide,
    required this.compact,
    required this.poster,
  });

  final TitleHero hero;
  final bool wide;

  /// A phone: a smaller title and actions spanning the width.
  final bool compact;

  /// The poster beside the copy carries the rating.
  final bool poster;

  List<MetaItem> _facts(ImdbTitle t, ImdbTitleDetails? d) {
    final episodes = d?.episodeCount;
    return [
      // With a poster, the rating rides on it.
      if (!poster && t.rating != null)
        MetaItem(
          t.rating!.toStringAsFixed(1),
          icon: Icons.star_rounded,
          technical: true,
        ),
      if (t.voteCount != null) MetaItem('${compactCount(t.voteCount!)} votes'),
      if (yearLabel(t) case final year?)
        MetaItem(year, icon: Icons.calendar_today_outlined),
      if (lengthLabel(t, d) case final length?)
        MetaItem(
          length,
          icon: t.canHaveEpisodes == true
              ? Icons.layers_outlined
              : Icons.schedule_rounded,
        ),
      if (t.canHaveEpisodes == true && episodes != null && episodes > 0)
        MetaItem(
          '${groupedCount(episodes)} episodes',
          icon: Icons.format_list_numbered_rounded,
        ),
      if (d?.certificate case final rated?) MetaItem(rated),
    ];
  }

  List<Widget> _parts(SentorrType type, {required bool short}) {
    final t = hero.title;
    final original = hero.details?.originalTitle;
    final people = _people(hero.details);
    // Parts that arrive with details always hold a slot, so their arrival
    // does not shift (and replay) the reveal of the parts after them.
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: Space.s12),
        child: OverlayBadge(kindLabel(t), icon: kindIcon(t)),
      ),
      Text(
        t.title,
        maxLines: short ? 2 : 3,
        overflow: TextOverflow.ellipsis,
        style:
            (wide
                    ? type.display
                    : compact
                    ? type.headlineCompact
                    : type.headline)
                .copyWith(color: OverlayColors.foreground),
      ),
      if (original == null || original == t.title)
        const SizedBox.shrink()
      else
        Padding(
          padding: const EdgeInsets.only(top: Space.s4),
          child: Text(
            original,
            style: type.bodySmall.copyWith(
              color: OverlayColors.foregroundSecondary,
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: Space.s12),
        child: MetaLine(
          _facts(t, hero.details),
          color: OverlayColors.foreground,
          style: type.bodySmall,
        ),
      ),
      // A short window keeps the actions in view: genres and credits
      // wait for the sections below.
      if (t.genres.isNotEmpty && !short)
        Padding(
          padding: const EdgeInsets.only(top: Space.s12),
          child: Wrap(
            spacing: Space.s8,
            runSpacing: Space.s8,
            children: [for (final g in t.genres) OverlayGenreChip(g)],
          ),
        ),
      if (t.plot case final plot? when plot.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: Space.s12),
          child: Text(
            plot,
            maxLines: short ? 2 : 5,
            overflow: TextOverflow.ellipsis,
            style: (wide ? type.bodyLarge : type.bodySmall).copyWith(
              color: OverlayColors.foregroundSecondary,
            ),
          ),
        ),
      if (people.isEmpty || short)
        const SizedBox.shrink()
      else
        Padding(
          padding: const EdgeInsets.only(top: Space.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Space.s4,
            children: [
              for (final (role, names) in people)
                _Credit(role: role, names: names),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: Space.s24),
        child: HeroActions(
          compact: compact,
          children: [
            SButton.primary(
              label: hero.playLabel,
              icon: Icons.play_arrow_rounded,
              onPressed: hero.onPlay,
            ),
            if (hero.onEpisodes != null)
              SButton(
                label: 'Episodes',
                icon: Icons.video_library_outlined,
                onPressed: hero.onEpisodes,
              ),
            ...hero.actions,
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, part) in _parts(
              context.type,
              short: context.screen.short,
            ).indexed)
              Reveal(
                delay: Duration(milliseconds: 60 * i),
                child: part,
              ),
          ],
        ),
      ),
    );
  }
}

/// Key people by role, in the source's order and wording: directors or
/// creators, writers, stars. A few names each; the cast row has the rest.
List<(String, String)> _people(ImdbTitleDetails? d) {
  final byRole = <String, List<String>>{};
  for (final c in d?.principalCredits ?? const <ImdbCredit>[]) {
    byRole.putIfAbsent(c.category, () => []).add(c.person.name);
  }
  return [
    for (final MapEntry(:key, :value) in byRole.entries.take(3))
      (key, value.take(3).join(', ')),
  ];
}

/// "Directors  Denis Villeneuve": the role muted, the names readable.
class _Credit extends StatelessWidget {
  const _Credit({required this.role, required this.names});

  final String role;
  final String names;

  @override
  Widget build(BuildContext context) {
    final type = context.type.bodySmall;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$role  ',
            style: type.copyWith(
              color: OverlayColors.foregroundMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: names,
            style: type.copyWith(color: OverlayColors.foreground),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
