import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/watch_activity.dart';
import '../../../imdb/models.dart';
import '../../../watching/models.dart';
import '../../../watching/notifier.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/confirm_dialog.dart';
import '../../components/cards/resume_card.dart';
import '../../components/cards/title_poster.dart';
import '../../components/title_artwork.dart';
import '../../components/title_link.dart';
import '../../shared/title_format.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_icons.dart';
import '../../shared/title_route.dart';
import '../../shared/layout/adaptive.dart';
import '../../shared/play_route.dart';
import 'async_shelf.dart';
import 'home_layout.dart';

WidgetBuilder _preview(WidgetRef ref, ImdbTitle t) =>
    (_) => PickUpPreview(
      title: t,
      onOpen: () => ref.openTitle(t),
      onPlay: () => ref.playOrPickUp(t),
    );

/// What the viewer can pick back up. [gutter] and [top] place it inside a
/// narrower column; [editable] lets each started item be removed, or all.
class ContinueWatchingShelf extends ConsumerWidget {
  const ContinueWatchingShelf({
    super.key,
    this.gutter,
    this.top = Space.s40,
    this.editable = false,
  });

  final double? gutter;
  final double top;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.read(watchHistoryProvider.notifier);
    return AsyncShelf<WatchEntry>(
      icon: Icons.history_rounded,
      title: 'Continue watching',
      count: (n) => '$n to continue',
      items: ref.watch(continueWatchingProvider),
      spec: HomeLayout.of(context).resume,
      gutter: gutter,
      top: top,
      action: editable && ref.watch(inProgressProvider).isNotEmpty
          ? _ClearProgress(onClear: history.clear)
          : null,
      onRetry: () => ref.invalidate(continueWatchingProvider),
      cardBuilder: (context, entry, _) {
        final show = entry.series ?? entry.title;
        return ResumeCard(
          key: ValueKey(entry.key),
          title: show.title,
          titleLink: TitleLink(
            title: show,
            season: entry.season,
            child: CardTitle(show.title, large: true),
          ),
          metaLink: entry.isEpisode
              ? TitleLink(
                  title: show,
                  season: entry.season,
                  episode: ImdbEpisode(
                    title: entry.title,
                    seasonNumber: entry.season,
                    episodeNumber: entry.episode,
                  ),
                  child: MetaLine([MetaItem(entry.title.title)]),
                )
              : null,
          meta: [
            if (entry.isEpisode)
              MetaItem(entry.title.title)
            else ...[
              MetaItem(kindLabel(show), icon: kindIcon(show)),
              if (show.genres.isNotEmpty)
                MetaItem(show.genres.take(2).join(', ')),
            ],
          ],
          chip: entry.isEpisode
              ? episodeCode(entry.season, entry.episode)
              : kindLabel(show),
          chipIcon: kindIcon(show),
          nextEpisode: entry.position == Duration.zero,
          progress: entry.progress,
          position: entry.position,
          runtime: entry.duration,
          artwork: TitleBackdrop(title: show, waitForBackdrop: true),
          onTap: () => ref.resume(entry),
          // A suggested next episode is not in the history to remove.
          onRemove: editable && entry.position > Duration.zero
              ? () => history.remove(entry.key)
              : null,
          preview: entry.isEpisode ? null : _preview(ref, show),
        );
      },
    );
  }
}

/// Clears all watch progress once confirmed; an icon on phones, where the
/// row's header has no room for words.
class _ClearProgress extends StatelessWidget {
  const _ClearProgress({required this.onClear});

  final Future<void> Function() onClear;

  Future<void> _clear(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Clear watch progress?',
      message: 'Everything you started plays from the start next time.',
      confirmLabel: 'Clear',
    );
    if (ok) await onClear();
  }

  @override
  Widget build(BuildContext context) => context.screen.compact
      ? SIconButton(
          icon: Icons.clear_all_rounded,
          tooltip: 'Clear all',
          onPressed: () => _clear(context),
        )
      : SButton.ghost(label: 'Clear all', onPressed: () => _clear(context));
}
