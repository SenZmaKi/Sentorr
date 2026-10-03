import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/notifier.dart';
import '../../components/app_shell.dart';
import '../../components/buttons.dart';
import '../../components/surface.dart';
import '../../shared/theme/theme.dart';
import 'home_layout.dart';

/// Heads the home page while offline, in place of the spotlight: what
/// still works, that it reconnects without help, and the way to downloads.
class OfflineNotice extends ConsumerWidget {
  const OfflineNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final compact = HomeLayout.of(context).compact;
    final hasDownloads = ref.watch(libraryProvider).isNotEmpty;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You’re offline',
          style: context.type.subtitle.copyWith(color: c.foreground),
        ),
        const SizedBox(height: Space.s4),
        Text(
          hasDownloads
              ? 'Your downloads still play. Sentorr reconnects on its own '
                    'and brings the rest back.'
              : 'Downloaded movies and episodes play without a connection. '
                    'Sentorr reconnects on its own and brings the rest back.',
          style: context.type.bodySmall.copyWith(color: c.foregroundMuted),
        ),
      ],
    );
    final button = hasDownloads
        ? SButton(
            label: 'Open Downloads',
            icon: Icons.download_done_rounded,
            onPressed: () => ref
                .read(appDestinationProvider.notifier)
                .go(AppDestination.downloads),
          )
        : null;
    final lead = Row(
      children: [
        DepthBox(
          style: context.depth.of(SurfaceDepth.raised),
          radius: Radii.control,
          width: ControlHeights.standard,
          height: ControlHeights.standard,
          child: Icon(
            Icons.cloud_off_rounded,
            size: IconSizes.control,
            color: c.warning,
          ),
        ),
        const SizedBox(width: Space.s12),
        Expanded(child: text),
        if (button != null && !compact) ...[
          const SizedBox(width: Space.s16),
          button,
        ],
      ],
    );
    return Semantics(
      liveRegion: true,
      child: Surface(
        child: button == null || !compact
            ? lead
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  lead,
                  const SizedBox(height: Space.s16),
                  button,
                ],
              ),
      ),
    );
  }
}
