import 'package:flutter/material.dart';

import '../../components/cards/episode_row_skeleton.dart';
import '../../components/season_chips_loading.dart';
import '../../components/section_header.dart';
import '../../components/skeleton.dart';
import '../../shared/theme/theme.dart';

class TitleEpisodesLoading extends StatelessWidget {
  const TitleEpisodesLoading({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(
        icon: Icons.video_library_outlined,
        title: 'Episodes',
        subtitleLink: Skeleton.text(
          sample: '99 seasons',
          style: context.type.bodySmall,
        ),
      ),
      const SizedBox(height: Space.s16),
      const SeasonChipsLoading(),
      const SizedBox(height: Space.s12),
      const EpisodeListSkeleton(),
    ],
  );
}
