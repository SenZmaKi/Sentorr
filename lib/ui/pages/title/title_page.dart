import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../imdb/providers.dart';
import '../../../player/models.dart';
import '../../../titles/pick_up.dart';
import '../../components/download_button.dart';
import '../../components/follow_button.dart';
import '../../components/load_error.dart';
import '../../components/motion.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_route.dart';
import '../../shared/play_route.dart';
import 'title_episodes.dart';
import 'title_hero.dart';
import 'title_shelves.dart';

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

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(titleDetailsProvider(_title.id));
    final d = details.value;
    final seasons = [...?d?.seasons.where((n) => n >= 0)]..sort();
    final pick = ref.watch(pickUpProvider(_title.id)).value;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _back},
      child: Focus(
        focusNode: _focus,
        child: ColoredBox(
          color: context.colors.surface,
          child: LayoutBuilder(
            builder: (context, box) {
              final gutter = box.maxWidth < 600 ? Space.s16 : Space.s24;
              final shelves = TitleShelfLayout(context, gutter: gutter);
              final cast = [
                ...?d?.credits.items.where((c) => c.kind == 'Cast'),
              ];
              Widget padded(Widget child) => Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: child,
              );
              final sections = <Widget>[
                padded(
                  TitleHero(
                    title: d?.title ?? _title,
                    details: d,
                    onBack: _back,
                    onPlay: () => ref.playFrom(d?.title ?? _title, pick),
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
                if (cast.isNotEmpty) CastShelf(cast: cast, layout: shelves),
                if (seasons.isNotEmpty)
                  padded(
                    TitleEpisodes(
                      key: _episodesKey,
                      series: _title,
                      seasons: seasons,
                      initialSeason: widget.route.season ?? pick?.season,
                    ),
                  ),
                if (d != null && d.recommendations.items.isNotEmpty)
                  RecommendationsShelf(
                    titles: d.recommendations.items,
                    layout: shelves,
                  ),
                ReviewsShelf(titleId: _title.id, layout: shelves),
              ];
              return ListView(
                padding: EdgeInsets.only(top: gutter, bottom: gutter * 2),
                children: [
                  for (final (i, s) in sections.indexed)
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : Space.s48),
                          child: s,
                        ),
                      ),
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
