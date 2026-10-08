import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../titles/episodes.dart';
import '../../components/chips.dart';
import '../../components/section_header.dart';
import '../../shared/theme/theme.dart';
import 'season_download_button.dart';
import 'season_watched_button.dart';
import 'episode_list.dart';

/// A series' episodes, one season at a time: season chips, then the
/// season's episodes in air order, paged on request.
class TitleEpisodes extends ConsumerStatefulWidget {
  const TitleEpisodes({
    super.key,
    required this.series,
    required this.seasons,
    this.initialSeason,
    this.episodeId,
  });

  final ImdbTitle series;
  final List<int> seasons;

  /// The season shown first; a later one shows it until the viewer picks a
  /// season themselves, since where they are in a series can arrive late.
  final int? initialSeason;
  final String? episodeId;

  @override
  ConsumerState<TitleEpisodes> createState() => _TitleEpisodesState();
}

class _TitleEpisodesState extends ConsumerState<TitleEpisodes> {
  late int _season = _initial;
  bool _picked = false;

  int get _initial => widget.seasons.contains(widget.initialSeason)
      ? widget.initialSeason!
      : widget.seasons.first;

  @override
  void didUpdateWidget(TitleEpisodes old) {
    super.didUpdateWidget(old);
    if (widget.episodeId != old.episodeId ||
        (!_picked && widget.initialSeason != old.initialSeason)) {
      _season = _initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (widget.series.id, _season);
    final episodes = ref.watch(seasonEpisodesProvider(key));
    final total = episodes.total;
    // A deep link can point beyond the first provider page. Keep loading
    // until found, exhausted, or failed; the provider guards duplicate loads.
    if (!_picked &&
        widget.episodeId != null &&
        !episodes.items.any((e) => e.title.id == widget.episodeId) &&
        episodes.hasMore &&
        !episodes.loadingMore &&
        episodes.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_picked) {
          ref.read(seasonEpisodesProvider(key).notifier).loadMore();
        }
      });
    }
    final today = DateTime.now();
    final lastAired = episodes.items
        .where((e) => e.releaseDate?.dateTime?.isAfter(today) == false)
        .map((e) => e.episodeNumber ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    final download = lastAired > 0
        ? Row(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.s4,
            children: [
              SeasonWatchedButton(
                series: widget.series,
                season: _season,
                lastAired: lastAired,
              ),
              SeasonDownloadButton(series: widget.series, season: _season),
            ],
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.video_library_outlined,
          title: 'Episodes',
          subtitle: widget.seasons.length == 1
              ? 'Season $_season'
              : '${widget.seasons.length} seasons',
          count: total == null ? null : '$total in season $_season',
          // With one season there are no chips to sit beside.
          action: widget.seasons.length == 1 ? download : null,
        ),
        if (widget.seasons.length > 1) ...[
          const SizedBox(height: Space.s16),
          // The season's download sits at the end of its chips, beside
          // the column of episode downloads below.
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  // Room for the chips' outset focus rings.
                  padding: const EdgeInsets.all(Space.s4),
                  child: Row(
                    spacing: Space.s8,
                    children: [
                      for (final n in widget.seasons)
                        SChip(
                          label: 'Season $n',
                          selected: n == _season,
                          onTap: () => setState(() {
                            _season = n;
                            _picked = true;
                          }),
                        ),
                    ],
                  ),
                ),
              ),
              if (download != null) ...[
                const SizedBox(width: Space.s8),
                // Lines up with the episode rows' download buttons.
                Padding(
                  padding: const EdgeInsets.only(right: Space.s12),
                  child: download,
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: Space.s12),
        EpisodeList(
          series: widget.series,
          season: _season,
          state: episodes,
          episodeId: _picked ? null : widget.episodeId,
        ),
      ],
    );
  }
}
