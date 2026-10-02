import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/catalog_rows.dart';
import '../../../home/series_updates.dart';
import '../../../home/watch_activity.dart';
import 'featured_section.dart';
import 'home_layout.dart';
import 'home_shelves.dart';
import 'spotlight_ambient.dart';

/// Streaming-style landing: a trending spotlight, personal rows (resume,
/// new episodes, new seasons), then IMDb catalog rows.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static const _sections = <Widget>[
    FeaturedSection(),
    ContinueWatchingShelf(),
    NewEpisodesShelf(),
    CatalogShelf(CatalogRow.trending),
    NewSeasonsShelf(),
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
    for (final row in CatalogRow.values) {
      ref.invalidate(catalogRowProvider(row));
    }
    ref
      ..invalidate(continueWatchingProvider)
      ..invalidate(seriesUpdatesProvider);
    await ref.read(featuredTitlesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => HomeLayout(
        width: box.maxWidth,
        textScaler: MediaQuery.textScalerOf(context),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: (box.maxWidth * 0.7).clamp(560, 1000),
              child: SpotlightAmbient(scroll: _scroll),
            ),
            RefreshIndicator(
              onRefresh: _refresh,
              child: Builder(builder: _list),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final gutter = HomeLayout.of(context).gutter;
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.only(top: gutter, bottom: gutter * 2),
      itemCount: _sections.length,
      itemBuilder: (context, i) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          // Shelves scroll under the gutter; the hero sits inside it.
          child: i == 0
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: _sections[i],
                )
              : _sections[i],
        ),
      ),
    );
  }
}
