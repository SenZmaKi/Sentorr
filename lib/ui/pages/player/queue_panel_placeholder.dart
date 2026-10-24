import 'package:flutter/material.dart';

import '../../components/buttons.dart';
import '../../components/cards/episode_row_skeleton.dart';
import '../../components/load_error.dart';
import '../../components/season_chips_loading.dart';
import '../../components/section_header.dart';
import '../../shared/theme/theme.dart';
import 'menu_rows.dart';
import 'player_layout.dart';

/// Occupies the normal panel slot before a queue is available.
class QueuePanelPlaceholder extends StatelessWidget {
  const QueuePanelPlaceholder({
    super.key,
    required this.title,
    required this.episodes,
    required this.onClose,
    required this.onRetry,
    this.failed = false,
  });
  final String title;
  final bool episodes, failed;
  final VoidCallback onClose, onRetry;

  @override
  Widget build(BuildContext context) {
    final dense = context.playerLayout.handheld;
    return PlayerMenuSurface(
      padding: EdgeInsets.all(dense ? Space.s12 : Space.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            icon: episodes
                ? Icons.video_library_outlined
                : Icons.playlist_play_rounded,
            title: episodes ? 'Episodes' : 'Up next',
            subtitle: title,
            action: SIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close (q)',
              onPressed: onClose,
            ),
          ),
          if (episodes) ...[
            SizedBox(height: dense ? Space.s8 : Space.s16),
            if (failed)
              SizedBox(height: context.density.control + Space.s8)
            else
              const SeasonChipsLoading(),
          ],
          SizedBox(height: dense ? Space.s8 : Space.s12),
          Expanded(
            child: failed
                ? Align(
                    alignment: Alignment.topLeft,
                    child: LoadError(
                      message: 'Couldn’t load what plays next.',
                      onRetry: onRetry,
                    ),
                  )
                : SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: EpisodeListSkeleton(
                      compact: true,
                      dense: dense,
                      divided: true,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
