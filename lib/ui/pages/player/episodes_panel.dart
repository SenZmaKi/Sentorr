import 'dart:math' as math;

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
import '../../components/load_error.dart';
import '../../components/section_header.dart';
import '../../components/title_artwork.dart';
import '../../shared/play_route.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'menu_rows.dart';

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
  });

  final PlayQueue queue;
  final ValueChanged<int> onJump;
  final VoidCallback onClose;

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
    final width = math.min(
      PlayerMetrics.queueWidth,
      MediaQuery.sizeOf(context).width - Space.s32,
    );
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
    return PlayerMenuSurface(
      width: width,
      padding: const EdgeInsets.all(Space.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            icon: episodes
                ? Icons.video_library_outlined
                : Icons.playlist_play_rounded,
            title: episodes ? 'Episodes' : 'Up next',
            subtitle: episodes ? series!.title : 'Keeps playing after this',
            count: episodes
                ? (state?.total == null ? null : '${state!.total} in S$season')
                : '${widget.queue.items.length - 1} queued',
            action: SIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close (q)',
              onPressed: widget.onClose,
            ),
          ),
          if (seasons.length > 1) ...[
            const SizedBox(height: Space.s16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(Space.s4),
              child: Row(
                spacing: Space.s8,
                children: [
                  for (final n in seasons)
                    SChip(
                      label: 'Season $n',
                      selected: n == season,
                      onTap: () => setState(() => _season = n),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.s12),
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
      selected: current,
      code: code,
      name: t.title,
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
            selected: i == widget.queue.index,
            name: item.name,
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
