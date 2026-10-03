import 'package:flutter/material.dart';

import '../components/inputs.dart';
import '../components/media.dart';
import '../components/selection.dart';
import '../shared/theme/theme.dart';
import 'sample_data.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.onOpen});

  final ValueChanged<SampleTitle> onOpen;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _filters = {'Movies', '2025+'};
  static const _all = [
    'Movies',
    'Series',
    '4K',
    '2025+',
    'Popular',
    'New episodes',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Discover',
                style: context.type.headline.copyWith(color: c.foreground),
              ),
            ),
            const STextField(
              width: 320,
              hint: 'Search movies and series',
              prefixIcon: Icons.search,
              semanticLabel: 'Search',
            ),
          ],
        ),
        const SizedBox(height: Space.s16),
        Wrap(
          spacing: Space.s8,
          runSpacing: Space.s8,
          children: [
            for (final f in _all)
              SChip(
                label: f,
                selected: _filters.contains(f),
                onTap: () => setState(
                  () => _filters.contains(f)
                      ? _filters.remove(f)
                      : _filters.add(f),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.s32),
        LayoutBuilder(
          builder: (context, box) {
            // Column count follows available width with nominal 160–220 tiles.
            final columns = ((box.maxWidth + Space.s16) / (190 + Space.s16))
                .floor()
                .clamp(2, 8);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: Space.s16,
                mainAxisSpacing: Space.s24,
                childAspectRatio: 2 / 3.55,
              ),
              itemCount: sampleTitles.length,
              itemBuilder: (context, i) {
                final t = sampleTitles[i];
                return MediaTile(
                  title: t.title,
                  metadata: t.metadata,
                  artwork: Artwork(hue: t.hue, seed: i),
                  onTap: () => widget.onOpen(t),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
