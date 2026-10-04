import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/catalog_rows.dart';
import '../../../imdb/models.dart';
import '../../../titles/pick_up.dart';
import '../../components/interactive.dart';
import '../../components/hero_frame.dart';
import '../../components/load_error.dart';
import '../../components/motion.dart';
import '../../shared/layout/adaptive.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import '../../components/cards/card_parts.dart';
import '../../shared/title_icons.dart';
import '../../shared/title_route.dart';
import '../../shared/play_route.dart';
import 'featured_hero.dart';
import 'featured_artwork.dart';
import 'spotlight_gestures.dart';
import 'spotlight_state.dart';

/// Spotlight over the top trending titles. Advances on its own, pausing
/// while hovered or focused, or once touched until the viewer swipes or
/// picks another title, and stays put under reduced motion.
class FeaturedSection extends ConsumerStatefulWidget {
  const FeaturedSection({super.key});

  @override
  ConsumerState<FeaturedSection> createState() => _FeaturedSectionState();
}

class _FeaturedSectionState extends ConsumerState<FeaturedSection>
    with SingleTickerProviderStateMixin {
  late final _hold = AnimationController(
    vsync: this,
    duration: Motion.spotlightHold,
  )..addStatusListener(_onHoldStatus);
  int _count = 0;
  bool _hovered = false;
  bool _focused = false;
  bool _touched = false;

  bool get _paused => _hovered || _focused || _touched || reduceMotion(context);

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _count < 2) return;
    _show((ref.read(spotlightIndexProvider) + 1) % _count);
  }

  void _show(int index) {
    ref.read(spotlightIndexProvider.notifier).show(index);
    _touched = false;
    _hold.value = 0;
    if (!_paused) _hold.forward();
  }

  void _setPause({bool? hovered, bool? focused, bool? touched}) {
    _hovered = hovered ?? _hovered;
    _focused = focused ?? _focused;
    _touched = touched ?? _touched;
    if (_paused) {
      _hold.stop();
    } else if (_count > 1) {
      _hold.forward();
    }
  }

  void _start(List<ImdbTitle> titles) {
    if (_count == titles.length) return;
    _count = titles.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setPause();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(featuredTitlesProvider)
        .when(
          data: (titles) {
            if (titles.isEmpty) return const SizedBox.shrink();
            _start(titles);
            final i = ref
                .watch(spotlightIndexProvider)
                .clamp(0, titles.length - 1);
            final t = titles[i];
            final pick = ref.watch(pickUpProvider(t.id)).value;
            return MouseRegion(
              onEnter: (_) => _setPause(hovered: true),
              onExit: (_) => _setPause(hovered: false),
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onFocusChange: (f) => _setPause(focused: f),
                child: SpotlightGestures(
                  onTouch: () => _setPause(touched: true),
                  onSwipe: (step) {
                    if (titles.length > 1) {
                      _show((i + step) % titles.length);
                    }
                  },
                  child: FeaturedHero(
                    title: t.title,
                    facts: _facts(t, compact: context.screen.compact),
                    genres: t.genres.take(3).toList(),
                    synopsis: t.plot ?? '',
                    badge: '#${i + 1} trending this week',
                    badgeIcon: Icons.trending_up_rounded,
                    artwork: FeaturedArtwork(titles: titles, index: i),
                    pager: titles.length < 2
                        ? null
                        : RepaintBoundary(
                            child: _Pager(
                              titles: titles,
                              index: i,
                              progress: _hold,
                              onSelect: _show,
                              // A phone swipes between titles, so its dots
                              // only show where it is.
                              indicator:
                                  context.screen.compact &&
                                  context.input.isTouch,
                            ),
                          ),
                    onPlay: () => ref.playFrom(t, pick),
                    playLabel: pickUpLabel(pick),
                    onDetails: () => ref.openTitle(t),
                  ),
                ),
              ),
            );
          },
          error: (_, _) => HeroFrame(
            child: Padding(
              padding: const EdgeInsets.all(Space.s24),
              child: LoadError(
                message:
                    "Couldn't load featured titles. Check your connection.",
                onRetry: () =>
                    ref.invalidate(catalogRowProvider(CatalogRow.trending)),
              ),
            ),
          ),
          loading: () => HeroFrame(
            background: ColoredBox(color: context.colors.surfaceControl),
            child: const SizedBox.shrink(),
          ),
        );
  }
}

/// A phone keeps to what fits one line: rating, kind, year and length.
List<MetaItem> _facts(ImdbTitle t, {required bool compact}) => [
  if (t.rating != null)
    MetaItem(
      t.rating!.toStringAsFixed(1),
      icon: Icons.star_rounded,
      technical: true,
    ),
  if (t.voteCount != null && !compact)
    MetaItem('${compactCount(t.voteCount!)} votes'),
  MetaItem(kindLabel(t), icon: kindIcon(t)),
  if (yearLabel(t) case final year?)
    MetaItem(year, icon: Icons.calendar_today_outlined),
  if (t.runtimeSeconds case final s? when t.canHaveEpisodes != true)
    MetaItem(durationLabel(Duration(seconds: s)), icon: Icons.schedule_rounded),
];

/// One dot per featured title. The current one is a wider track that fills
/// as its turn runs, so position is not conveyed by color alone.
class _Pager extends StatelessWidget {
  const _Pager({
    required this.titles,
    required this.index,
    required this.progress,
    required this.onSelect,
    this.indicator = false,
  });

  final List<ImdbTitle> titles;
  final int index;
  final Animation<double> progress;
  final ValueChanged<int> onSelect;

  /// Dots without their own targets, set close together; assistive
  /// technology steps through titles as it would a slider.
  final bool indicator;

  Widget _dot(BuildContext context, int n, {bool hovered = false}) =>
      AnimatedContainer(
        duration: Motion.reveal,
        curve: Motion.change,
        width: n == index ? Space.s32 : Space.s8,
        height: Space.s8,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: hovered
              ? OverlayColors.foregroundSecondary
              : OverlayColors.inactiveTrack,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: n != index
            ? null
            : AnimatedBuilder(
                animation: progress,
                builder: (context, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: reduceMotion(context) ? 1 : progress.value,
                  child: const ColoredBox(color: OverlayColors.foreground),
                ),
              ),
      );

  @override
  Widget build(BuildContext context) {
    final count = titles.length;
    if (indicator) {
      return Semantics(
        label: 'Featured title',
        value: '${index + 1} of $count, ${titles[index].title}',
        increasedValue: '${(index + 1) % count + 1} of $count',
        decreasedValue: '${(index - 1) % count + 1} of $count',
        onIncrease: () => onSelect((index + 1) % count),
        onDecrease: () => onSelect((index - 1) % count),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.s8,
          children: [for (var n = 0; n < count; n++) _dot(context, n)],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (n, t) in titles.indexed)
          Interactive(
            onTap: () => onSelect(n),
            selected: n == index,
            semanticLabel: 'Feature ${t.title}',
            borderRadius: Radii.full,
            focusColor: OverlayColors.focus,
            // 24 on pointer; 48 on touch, keeping the 8 dot.
            builder: (context, s) => MinTarget(
              child: Padding(
                padding: const EdgeInsets.all(Space.s8),
                child: _dot(context, n, hovered: s.hovered),
              ),
            ),
          ),
      ],
    );
  }
}
