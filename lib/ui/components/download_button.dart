import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/models.dart';
import '../../library/notifier.dart';
import '../../player/models.dart';
import '../shared/download_actions.dart';
import '../shared/theme/theme.dart';
import 'app_shell.dart';
import 'buttons.dart';
import 'menu.dart';

/// Downloads [item] for offline viewing and shows how far along it is:
/// a ring fills as it downloads, then a check. Once started, pressing it
/// opens a menu to pause, cancel, play, show or delete.
class DownloadButton extends ConsumerWidget {
  const DownloadButton({
    super.key,
    required this.item,
    this.labelled = false,
    this.menu = true,
  });

  final PlaybackItem item;

  /// A secondary button with words, e.g. on the title page; otherwise an
  /// icon button for rows and cards.
  final bool labelled;

  /// False where an anchored menu cannot live, e.g. a hover preview that
  /// closes on any tap: a started download then opens the Downloads page,
  /// a finished one plays.
  final bool menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlineStateProvider(item.id));
    final look = _Look.of(context, state);
    final actions = _actions(context, ref, state);
    Widget trigger(VoidCallback? onTap) => labelled
        ? Tooltip(
            message: look.tooltip,
            child: SButton(
              label: look.label,
              leading: look.glyph,
              onPressed: onTap,
            ),
          )
        : SIconButton(
            icon: Icons.download_rounded,
            glyph: look.glyph,
            tooltip: look.tooltip,
            onPressed: onTap,
          );
    return switch (state) {
      NotDownloaded() => trigger(() => ref.download(item)),
      Planning() => trigger(null),
      Downloaded(:final entry) when !menu => trigger(
        () => ref.playDownload(entry),
      ),
      DownloadFailed() when !menu => trigger(() => ref.download(item)),
      _ when !menu => trigger(
        () => ref
            .read(appDestinationProvider.notifier)
            .go(AppDestination.downloads),
      ),
      _ => ActionMenu(
        actions: actions,
        builder: (context, menu) =>
            trigger(() => menu.isOpen ? menu.close() : menu.open()),
      ),
    };
  }

  List<MenuAction> _actions(
    BuildContext context,
    WidgetRef ref,
    OfflineState state,
  ) => switch (state) {
    Downloading(:final entry, :final status) => [
      if (status == OfflineProgress.paused)
        MenuAction(
          'Resume download',
          icon: Icons.play_arrow_rounded,
          onPressed: () => ref.resumeDownload(entry),
        )
      else
        MenuAction(
          'Pause download',
          icon: Icons.pause_rounded,
          onPressed: () => ref.pauseDownload(entry),
        ),
      MenuAction(
        'Cancel download',
        icon: Icons.close_rounded,
        destructive: true,
        onPressed: () => ref.deleteDownload(context, entry, finished: false),
      ),
    ],
    Downloaded(:final entry) => [
      MenuAction(
        'Play',
        icon: Icons.play_arrow_rounded,
        onPressed: () => ref.playDownload(entry),
      ),
      MenuAction(
        'Show in folder',
        icon: Icons.folder_open_rounded,
        onPressed: () => ref.showDownload(entry),
      ),
      MenuAction(
        'Delete download',
        icon: Icons.delete_outline_rounded,
        destructive: true,
        onPressed: () => ref.deleteDownload(context, entry),
      ),
    ],
    DownloadFailed(:final entry) => [
      MenuAction(
        'Try again',
        icon: Icons.refresh_rounded,
        onPressed: () => ref.download(item),
      ),
      MenuAction(
        'Remove',
        icon: Icons.close_rounded,
        destructive: true,
        onPressed: () => ref.deleteDownload(context, entry, finished: false),
      ),
    ],
    _ => const [],
  };
}

/// The glyph, words and tooltip for a download's state.
class _Look {
  const _Look(this.glyph, this.label, this.tooltip);
  final Widget glyph;
  final String label, tooltip;

  static _Look of(BuildContext context, OfflineState state) {
    final c = context.colors;
    String percent(double p) => '${(p * 100).floor()}%';
    return switch (state) {
      NotDownloaded() => _Look(
        Icon(
          Icons.download_rounded,
          size: IconSizes.control,
          color: c.foreground,
        ),
        'Download',
        'Download',
      ),
      Planning() => const _Look(
        DownloadRing(),
        'Preparing',
        'Finding a torrent to download',
      ),
      Downloading(:final progress, :final status) => switch (status) {
        OfflineProgress.preparing => const _Look(
          DownloadRing(),
          'Preparing',
          'Getting the torrent ready',
        ),
        OfflineProgress.queued => _Look(
          DownloadRing(value: progress, glyph: Icons.more_horiz_rounded),
          'Queued',
          'Waiting to download · ${percent(progress)}',
        ),
        OfflineProgress.downloading => _Look(
          DownloadRing(value: progress, glyph: Icons.arrow_downward_rounded),
          'Downloading ${percent(progress)}',
          'Downloading · ${percent(progress)}',
        ),
        OfflineProgress.paused => _Look(
          DownloadRing(value: progress, glyph: Icons.pause_rounded),
          'Paused ${percent(progress)}',
          'Paused · ${percent(progress)}',
        ),
      },
      Downloaded() => _Look(
        Icon(
          Icons.download_done_rounded,
          size: IconSizes.control,
          color: c.success,
        ),
        'Downloaded',
        'Downloaded · watch offline',
      ),
      DownloadFailed(:final error) => _Look(
        Icon(
          Icons.error_outline_rounded,
          size: IconSizes.control,
          color: c.error,
        ),
        'Download failed',
        error == null ? 'Download failed' : 'Download failed · $error',
      ),
    };
  }
}

/// A download's share as a ring on an inset track, around a small glyph
/// naming its state; spinning while the amount is unknown.
class DownloadRing extends StatelessWidget {
  const DownloadRing({super.key, this.value, this.glyph});

  /// 0–1; null while preparing.
  final double? value;
  final IconData? glyph;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox.square(
      dimension: IconSizes.control,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 2,
              color: c.action,
              backgroundColor: c.surfaceInset,
              strokeCap: StrokeCap.round,
            ),
          ),
          if (glyph != null) Icon(glyph, size: 12, color: c.foreground),
        ],
      ),
    );
  }
}
