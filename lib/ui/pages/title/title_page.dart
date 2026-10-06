import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../imdb/providers.dart';
import '../../../player/models.dart';
import '../../../player/prefetch.dart';
import '../../../player/queue_builder.dart';
import '../../../titles/pick_up.dart';
import '../../components/download_button.dart';
import '../../components/follow_button.dart';
import '../../components/load_error.dart';
import '../../components/motion.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_route.dart';
import '../../shared/play_route.dart';
import 'cast_column.dart';
import 'title_episodes.dart';
import 'title_hero.dart';
import 'title_shelves.dart';
import '../../shared/layout/adaptive.dart';

/// Everything about one title: a hero carrying its details, cast, episodes
/// for series, related titles and reviews. Opens over the current
/// destination; system Back, Escape or the hero's Back button return to it.
class TitlePage extends ConsumerStatefulWidget {
  const TitlePage({super.key, required this.route});

  final TitleRoute route;

  @override
  ConsumerState<TitlePage> createState() => _TitlePageState();
}

class _TitlePageState extends ConsumerState<TitlePage> {
  final _episodesKey = GlobalKey();
  final _scroll = ScrollController();
  bool _seekingEpisode = false;
  final _focus = FocusNode(debugLabel: 'Title page');

  @override
  void initState() {
    super.initState();
    // Take focus from the page it covers (autofocus yields to an existing
    // focus), so Escape and keyboard traversal start here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  ImdbTitle get _title => widget.route.title;

  void _back() => ref.read(titleRoutesProvider.notifier).back();

  void _showEpisodes() {
    final target = _episodesKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: reduceMotion(context) ? Duration.zero : Motion.artwork,
      curve: Motion.change,
    );
  }

  void _seekEpisodeSection() {
    if (_seekingEpisode || widget.route.episodeId == null) return;
    _seekingEpisode = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ListView lays out sections lazily. Bring the episode section into
      // layout first; its destination row then scrolls to the exact episode.
      while (mounted &&
          _episodesKey.currentContext == null &&
          _scroll.hasClients) {
        final position = _scroll.position;
        final next = (position.pixels + position.viewportDimension).clamp(
          0.0,
          position.maxScrollExtent,
        );
        if (next <= position.pixels) break;
        _scroll.jumpTo(next);
        await WidgetsBinding.instance.endOfFrame;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(titleDetailsProvider(_title.id));
    final d = details.value;
    final seasons = [...?d?.seasons.where((n) => n >= 0)]..sort();
    final pickUp = ref.watch(pickUpProvider(_title.id));
    final pick = ref.watch(pickUpPresentationProvider(_title.id));
    if (!pickUp.isLoading) {
      final request = pick?.item == null
          ? PlayTitle(d?.title ?? _title)
          : requestFor(pick!.item!);
      ref.watch(mediaTorrentPrefetchProvider(PrefetchRequest(request)));
    }
    if (seasons.isNotEmpty) _seekEpisodeSection();
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _back},
      child: Focus(
        focusNode: _focus,
        child: ColoredBox(
          color: context.colors.surface,
          child: LayoutBuilder(
            builder: (context, box) {
              final shelves = TitleShelfLayout(
                context,
                layout: LayoutSize(box.biggest),
              );
              final gutter = shelves.gutter;
              final cast = [
                ...?d?.credits.items.where((c) => c.kind == 'Cast'),
              ];
              Widget padded(Widget child) =>
                  Padding(padding: shelves.insets.horizontal, child: child);
              // Large layouts keep the cast beside a series' episodes rather
              // than as a row above them.
              final castBeside =
                  shelves.layout.large && cast.isNotEmpty && seasons.isNotEmpty;
              final episodes = seasons.isEmpty
                  ? null
                  : TitleEpisodes(
                      key: _episodesKey,
                      series: _title,
                      seasons: seasons,
                      initialSeason: widget.route.season ?? pick?.season,
                      episodeId: widget.route.episodeId,
                    );
              final sections = <Widget>[
                padded(
                  TitleHero(
                    title: d?.title ?? _title,
                    details: d,
                    onBack: _back,
                    onPlay: () => ref.playOrPickUp(d?.title ?? _title),
                    playLabel: pickUpLabel(pick),
                    onEpisodes: seasons.isEmpty ? null : _showEpisodes,
                    actions: [
                      if ((d?.title ?? _title).canHaveEpisodes == true)
                        FollowButton(series: d?.title ?? _title)
                      else if (d != null)
                        DownloadButton(
                          item: PlaybackItem(title: d.title),
                          labelled: true,
                        ),
                    ],
                  ),
                ),
                if (details.hasError && d == null)
                  padded(
                    LoadError(
                      message:
                          "Couldn't load this title's details. "
                          'Check your connection.',
                      onRetry: () =>
                          ref.invalidate(titleDetailsProvider(_title.id)),
                    ),
                  ),
                // Who is in it reads as part of the title's information, so
                // it follows the hero, ahead of the episode list.
                if (cast.isNotEmpty && !castBeside)
                  CastShelf(cast: cast, layout: shelves),
                if (episodes != null)
                  padded(
                    castBeside
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: Space.s32,
                            children: [
                              Expanded(child: episodes),
                              SizedBox(
                                width: CastColumn.width,
                                child: CastColumn(cast: cast),
                              ),
                            ],
                          )
                        : episodes,
                  ),
                if (d != null && d.recommendations.items.isNotEmpty)
                  RecommendationsShelf(
                    titles: d.recommendations.items,
                    layout: shelves,
                  ),
                ReviewsShelf(titleId: _title.id, layout: shelves),
              ];
              return ListView(
                controller: _scroll,
                padding: EdgeInsets.only(top: gutter, bottom: gutter * 2),
                children: [
                  // Shelves span the page; everything else is padded into
                  // the content column.
                  for (final (i, s) in sections.indexed)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : Space.s48),
                      child: s,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
