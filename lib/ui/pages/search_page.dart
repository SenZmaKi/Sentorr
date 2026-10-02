import 'package:flutter/material.dart';

import '../components/inputs.dart';
import '../shared/theme/theme.dart';
import 'page_scaffold.dart';

/// Search entry point; results, filters and IMDb wiring come later.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PageScaffold(
      title: 'Search',
      children: [
        const STextField(
          hint: 'Search movies and series',
          prefixIcon: Icons.search,
          semanticLabel: 'Search movies and series',
        ),
        const SizedBox(height: Space.s64),
        Icon(Icons.movie_filter_outlined, size: 40, color: c.foregroundMuted),
        const SizedBox(height: Space.s12),
        Text(
          'Find something to watch',
          textAlign: TextAlign.center,
          style: context.type.subtitle.copyWith(color: c.foreground),
        ),
        const SizedBox(height: Space.s4),
        Text(
          'Search by title, then pick a release to stream.',
          textAlign: TextAlign.center,
          style: context.type.bodySmall.copyWith(color: c.foregroundSecondary),
        ),
      ],
    );
  }
}
