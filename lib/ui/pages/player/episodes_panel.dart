import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../imdb/providers.dart';
import '../../../player/models.dart';
import '../../../titles/episodes.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/cards/episode_row.dart';
import '../../components/chips.dart';
import '../../components/download_button.dart';
import '../../components/title_link.dart';
import '../title/season_download_button.dart';
import '../../components/load_error.dart';
import '../../components/section_header.dart';
import '../../components/title_artwork.dart';
import '../../shared/play_route.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'menu_rows.dart';
import 'player_layout.dart';

/// The title page's Episodes section, brought beside the picture: section
/// header, season chips and episode rows, on a floating panel. The playing
/// episode is marked and scrolled into view. After a movie, it lists what
/// plays next instead.
class EpisodesPanel extends ConsumerStatefulWidget {
  const EpisodesPanel({
    super.key,
    required this.queue,
    required this.onJump,
    required this.onClose,
    this.onBrowse,
  });

  final PlayQueue queue;
  final ValueChanged<int> onJump;
  final VoidCallback onClose;
  final VoidCallback? onBrowse;

  @override
  ConsumerState<EpisodesPanel> createState() => _EpisodesPanelState();
}

class _EpisodesPanelState extends ConsumerState<EpisodesPanel> {
  final _currentKey = GlobalKey();
  late int? _season = widget.queue.current.season;
  bool _scrolled = false;

  PlaybackItem get _current => widget.queue.current;

  void _revealCurrent() {
    if (_scrolled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _currentKey.currentContext;
      if (target == null) return;
      _scrolled = true;
      Scrollable.ensureVisible(target, alignment: 0.2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final episodes = widget.queue.kind == QueueKind.episodes;
    final series = _current.series;
    final seasons = series == null
        ? const <int>[]
        : ref
                  .watch(titleDetailsProvider(series.id))
                  .whenOrNull(data: (d) => d.seasons) ??
              [?_season];
    final season = _season;
    final state = series != null && season != null
        ? ref.watch(seasonEpisodesProvider((series.id, season)))
        : null;
    final dense = context.playerLayout.handheld;
    final downloadable =
        episodes &&
        series != null &&
        season != null &&
        state?.items.any(
              (e) => e.releaseDate?.dateTime?.isAfter(DateTime.now()) == false,
            ) ==
            true;
    // Sized by the player's panel slot.
    return PlayerMenuSurface(
      padding: EdgeInsets.all(dense ? Space.s12 : Space.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            icon: episodes
                ? Icons.video_library_outlined
                : Icons.playlist_play_rounded,
            title: episodes ? 'Episodes' : 'Up next',
            subtitle: episodes ? series!.title : 'Keeps playing after this',
            subtitleLink: episodes && series != null
                ? TitleLink(
                    title: series,
                    season: season,
                    beforeOpen: widget.onBrowse,
                    child: Text(
                      series.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.bodySmall.copyWith(
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  )
                : null,
            count: episodes
                ? (state?.total == null ? null : '${state!.total} in S$season')
                : '${widget.queue.items.length - 1} queued',
            action: SIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close (q)',
              onPressed: widget.onClose,
            ),
          ),
          if (seasons.length > 1 || downloadable) ...[
            SizedBox(height: dense ? Space.s8 : Space.s16),
            Row(
              children: [
                Expanded(
                  child: seasons.length > 1
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.all(dense ? Space.s2 : Space.s4),
                          child: Row(
                            spacing: dense ? Space.s4 : Space.s8,
                            children: [
                              for (final n in seasons)
                                SChip(
                                  label: 'Season $n',
                                  selected: n == season,
                                  onTap: () => setState(() => _season = n),
                                ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (downloadable)
                  SeasonDownloadButton(series: series, season: season),
              ],
            ),
          ],
          SizedBox(height: dense ? Space.s8 : Space.s12),
          Expanded(
            child: episodes && state != null
                ? _seasonList(series!, season!, state)
                : _queueList(),
          ),
        ],
      ),
    );
  }

  Widget _seasonList(ImdbTitle series, int season, SeasonEpisodes state) {
    final notifier = ref.read(
      seasonEpisodesProvider((series.id, season)).notifier,
    );
    if (state.loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (state.items.isEmpty) {
      return state.error != null
          ? LoadError(
              message: "Couldn't load season $season. Check your connection.",
              onRetry: notifier.retry,
            )
          : Text(
              'No episodes are listed for season $season yet.',
              style: context.type.bodySmall.copyWith(
                color: context.colors.foregroundSecondary,
              ),
            );
    }
    _revealCurrent();
    return ListView(
      children: [
        for (final (i, e) in state.items.indexed) ...[
          if (i > 0) const Divider(),
          _episodeRow(series, season, e),
        ],
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: Space.s12),
            child: Center(
              child: SButton(
                label: 'Show more episodes',
                icon: Icons.expand_more_rounded,
                loading: state.loadingMore,
                onPressed: notifier.loadMore,
              ),
            ),
          ),
      ],
    );
  }

  Widget _episodeRow(ImdbTitle series, int season, ImdbEpisode e) {
    final t = e.title;
    final current = t.id == _current.id;
    final aired = e.releaseDate?.dateTime;
    final upcoming = aired != null && aired.isAfter(DateTime.now());
    final code = episodeCode(e.seasonNumber ?? season, e.episodeNumber);
    final inQueue = widget.queue.items.indexWhere((i) => i.id == t.id);
    final VoidCallback? play = current || upcoming
        ? null
        : () => inQueue >= 0
              ? widget.onJump(inQueue)
              : ref.playEpisode(series, e, season: season);
    final still = t.poster != null
        ? TitleArtwork(image: t.poster)
        : TitleBackdrop(title: series);
    return EpisodeRow(
      key: current ? _currentKey : null,
      compact: true,
      dense: context.playerLayout.handheld,
      selected: current,
      code: code,
      name: t.title,
      nameLink: TitleLink(
        title: series,
        episode: e,
        season: season,
        beforeOpen: widget.onBrowse,
        child: CardTitle(t.title, large: true),
      ),
      trailing: upcoming
          ? null
          : DownloadButton(
              item: PlaybackItem.episode(series, e, season: season),
            ),
      meta: [
        if (aired != null)
          MetaItem(
            upcoming ? 'Airs ${dateLabel(aired)}' : dateLabel(aired),
            icon: Icons.event_outlined,
          ),
        if (t.rating != null)
          MetaItem(
            t.rating!.toStringAsFixed(1),
            icon: Icons.star_rounded,
            technical: true,
          ),
      ],
      plot: t.plot,
      duration: t.runtimeSeconds == null
          ? null
          : stampLabel(Duration(seconds: t.runtimeSeconds!)),
      artwork: still,
      semanticLabel: current
          ? 'Now playing: $code, ${t.title}'
          : 'Play $code, ${t.title}',
      onTap: play,
    );
  }

  Widget _queueList() {
    final items = widget.queue.items;
    _revealCurrent();
    return ListView(
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) const Divider(),
          EpisodeRow(
            key: i == widget.queue.index ? _currentKey : null,
            compact: true,
            dense: context.playerLayout.handheld,
            selected: i == widget.queue.index,
            name: item.name,
            nameLink: TitleLink(
              title: item.series ?? item.title,
              episode: item.isEpisode
                  ? ImdbEpisode(
                      title: item.title,
                      seasonNumber: item.season,
                      episodeNumber: item.episode,
                    )
                  : null,
              season: item.season,
              beforeOpen: widget.onBrowse,
              child: CardTitle(item.name, large: true),
            ),
            trailing: DownloadButton(item: item),
            meta: [
              if (item.title.rating != null)
                MetaItem(
                  item.title.rating!.toStringAsFixed(1),
                  icon: Icons.star_rounded,
                  technical: true,
                ),
              if (item.title.genres.isNotEmpty)
                MetaItem(item.title.genres.take(2).join(', ')),
            ],
            plot: item.title.plot,
            duration: item.runtime == null ? null : stampLabel(item.runtime!),
            artwork: TitleBackdrop(title: item.title),
            semanticLabel: 'Play ${item.name}',
            onTap: i == widget.queue.index ? null : () => widget.onJump(i),
          ),
        ],
      ],
    );
  }
}
