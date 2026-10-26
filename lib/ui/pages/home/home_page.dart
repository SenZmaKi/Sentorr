import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/catalog_rows.dart';
import '../../../home/more_like.dart';
import '../../../home/series_updates.dart';
import '../../../home/watch_activity.dart';
import '../../../shared/net/online.dart';
import '../../../lists/models.dart';
import '../../components/motion.dart';
import '../../components/hover_preview.dart';
import 'downloaded_shelf.dart';
import 'list_shelf.dart';
import 'featured_section.dart';
import '../../shared/layout/layout_size.dart';
import 'home_layout.dart';
import 'home_section.dart';
import 'continue_shelf.dart';
import 'continuity_card.dart';
import 'home_shelves.dart';
import 'offline_notice.dart';
import 'spotlight_ambient.dart';

/// Streaming-style landing: a trending spotlight, personal rows (resume,
/// new releases, more like something watched), then IMDb
/// catalog rows. Offline, a notice and the finished downloads lead instead,
/// rows that failed step aside, and everything reloads once back online.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();
  int? _previewSection;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static const _sections = <Widget>[
    FeaturedSection(),
    ContinuityCard(),
    ContinueWatchingShelf(),
    NewEpisodesShelf(),
    ListShelf(WatchStatus.planned),
    CatalogShelf(CatalogRow.trending),
    MoreLikeShelf(),
    ..._catalog,
  ];

  static const _offlineSections = <Widget>[
    OfflineNotice(),
    ContinuityCard(),
    ContinueWatchingShelf(),
    DownloadedShelf(),
    NewEpisodesShelf(),
    ListShelf(WatchStatus.planned),
    CatalogShelf(CatalogRow.trending),
    MoreLikeShelf(),
    ..._catalog,
  ];

  static const _catalog = <Widget>[
    CatalogShelf(CatalogRow.newReleases),
    CatalogShelf(CatalogRow.popularSeries),
    CatalogShelf(CatalogRow.popularMovies),
    CatalogShelf(CatalogRow.topRated),
    CatalogShelf(CatalogRow.action),
    CatalogShelf(CatalogRow.comedy),
    CatalogShelf(CatalogRow.sciFi),
    CatalogShelf(CatalogRow.animation),
    CatalogShelf(CatalogRow.horror),
  ];

  Future<void> _refresh() async {
    // Offline, pulling checks the connection; coming back reloads.
    if (!ref.read(onlineProvider)) {
      return ref.read(onlineProvider.notifier).check();
    }
    _reload();
    await ref.read(featuredTitlesProvider.future);
  }

  void _reload() {
    for (final row in CatalogRow.values) {
      ref.invalidate(catalogRowProvider(row));
    }
    ref
      ..invalidate(continueWatchingProvider)
      ..invalidate(moreLikeProvider)
      ..invalidate(seriesUpdatesProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(onlineProvider, (wasOnline, online) {
      if (wasOnline == false && online) _reload();
    });
    final online = ref.watch(onlineProvider);
    return LayoutBuilder(
      builder: (context, box) => HomeLayout(
        layout: LayoutSize(box.biggest),
        textScaler: MediaQuery.textScalerOf(context),
        child: Stack(
          children: [
            // The wash belongs to the spotlight, which steps aside offline.
            if (online)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: (box.maxWidth * 0.7).clamp(560, 1000),
                child: SpotlightAmbient(scroll: _scroll),
              ),
            RefreshIndicator(
              onRefresh: _refresh,
              child: RevealMemory(child: Builder(builder: _list)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final layout = HomeLayout.of(context);
    final gutter = layout.gutter;
    final sections = ref.watch(onlineProvider) ? _sections : _offlineSections;
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: gutter)),
        // Separate slivers measure every preceding section exactly, even when
        // its shelf is empty, rather than estimating lazy-list child offsets.
        for (var i = 0; i < sections.length; i++)
          HomeSection(
            preserveFollowing: _previewSection != null && i < _previewSection!,
            child: NotificationListener<HoverPreviewVisibility>(
              onNotification: (notice) {
                if (notice.visible) {
                  setState(() => _previewSection = i);
                } else {
                  // Menu actions can dismiss the preview before the list's
                  // new geometry is laid out. Retain its anchor for that frame.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _previewSection == i) {
                      setState(() => _previewSection = null);
                    }
                  });
                }
                return true;
              },
              child: i == 0
                  ? Padding(
                      padding: layout.insets.horizontal,
                      child: sections[i],
                    )
                  : sections[i],
            ),
          ),
        SliverPadding(padding: EdgeInsets.only(bottom: gutter * 2)),
      ],
    );
  }
}
