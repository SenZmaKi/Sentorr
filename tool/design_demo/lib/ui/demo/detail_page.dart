import 'package:flutter/material.dart';

import '../components/buttons.dart';
import '../components/media.dart';
import '../components/navigation.dart';
import '../components/overlays.dart';
import '../components/status.dart';
import '../components/surface.dart';
import '../shared/theme/theme.dart';
import 'sample_data.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.title, required this.onPlay});

  final SampleTitle title;
  final VoidCallback onPlay;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  int _selected = 1;
  String _tab = 'torrents';
  bool _watchlisted = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(
          title: widget.title,
          watchlisted: _watchlisted,
          onPlay: widget.onPlay,
          onWatchlist: () => setState(() => _watchlisted = !_watchlisted),
        ),
        const SizedBox(height: Space.s32),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            'A deep-space relay engineer begins receiving transmissions from a station '
            'that went silent decades ago, and must decide whether to answer.',
            style: context.type.bodyLarge.copyWith(
              color: c.foregroundSecondary,
            ),
          ),
        ),
        const SizedBox(height: Space.s32),
        Row(
          children: [
            SegmentedTabs(
              value: _tab,
              segments: const {
                'torrents': 'Sources',
                'files': 'Files',
                'details': 'Details',
              },
              onChanged: (v) => setState(() => _tab = v),
            ),
            const Spacer(),
            Text(
              '${sampleTorrents.length} results',
              style: context.type.bodySmall.copyWith(color: c.foregroundMuted),
            ),
          ],
        ),
        const SizedBox(height: Space.s16),
        Surface(
          padding: const EdgeInsets.all(Space.s8),
          child: Column(
            children: [
              for (final (i, t) in sampleTorrents.indexed) ...[
                if (i > 0)
                  const Divider(indent: Space.s16, endIndent: Space.s16),
                TorrentRow(
                  filename: t.filename,
                  quality: t.quality,
                  size: t.size,
                  seeders: t.seeders,
                  status: t.status,
                  selected: _selected == i,
                  onTap: () => setState(() => _selected = i),
                  action: t.status == TransferStatus.failed
                      ? SIconButton(
                          icon: Icons.refresh,
                          tooltip: 'Retry',
                          onPressed: () {},
                        )
                      : SIconButton(
                          icon: Icons.play_arrow_rounded,
                          tooltip: 'Stream this source',
                          onPressed: widget.onPlay,
                        ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.s24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: Space.s8,
          children: [
            SButton.destructive(
              label: 'Remove cached data',
              icon: Icons.delete_outline,
              onPressed: () => showSDialog(
                context,
                title: 'Remove cached data?',
                body: 'Downloaded pieces for this title will be deleted. You can stream it again later.',
                actions: (ctx) => [
                  SButton.ghost(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  SButton.destructive(
                    label: 'Remove',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.watchlisted,
    required this.onPlay,
    required this.onWatchlist,
  });

  final SampleTitle title;
  final bool watchlisted;
  final VoidCallback onPlay;
  final VoidCallback onWatchlist;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final titleStyle = (wide ? context.type.display : context.type.headline)
        .copyWith(color: OverlayColors.foreground);
    return DepthBox(
      style: context.depth.of(SurfaceDepth.panel),
      radius: Radii.panel,
      height: wide ? 420 : 320,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.panel),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Artwork(hue: title.hue, seed: 7),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: OverlayColors.artworkFade,
                  stops: [0.35, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.s32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.title, style: titleStyle),
                  const SizedBox(height: Space.s8),
                  Text(
                    '${title.year} · ${title.kind} · 2h 14m · Sci-fi, Drama',
                    style: context.type.bodySmall.copyWith(
                      color: OverlayColors.foregroundSecondary,
                    ),
                  ),
                  const SizedBox(height: Space.s24),
                  ImageOverlayContext(
                    child: Row(
                      spacing: Space.s8,
                      children: [
                        SButton.primary(
                          label: 'Play',
                          icon: Icons.play_arrow_rounded,
                          onPressed: onPlay,
                        ),
                        SButton(
                          label: watchlisted ? 'In watchlist' : 'Watchlist',
                          icon: watchlisted ? Icons.check : Icons.add,
                          onPressed: onWatchlist,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
