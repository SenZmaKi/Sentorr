import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/models.dart';
import '../../library/notifier.dart';
import '../../sync/elsewhere.dart';
import '../../sync/payload.dart';
import '../shared/download_actions.dart';
import '../shared/theme/theme.dart';
import 'app_shell.dart';
import 'cards/card_parts.dart';
import 'download_button.dart';
import 'menu.dart';

/// A [DownloadButton] for an item not on this device but on a paired one:
/// a devices glyph once it is downloaded there, a quieter ring while it
/// downloads there. Its menu plays it from there, copies it here once it
/// is finished, or downloads it here anyway.
class ElsewhereButton extends ConsumerWidget {
  const ElsewhereButton({
    super.key,
    required this.elsewhere,
    this.labelled = false,
    this.menu = true,
  });

  final Elsewhere elsewhere;
  final bool labelled;

  /// False inside a hover preview: a finished item plays from its device,
  /// one on its way opens the Downloads page.
  final bool menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final e = elsewhere;
    final percent = '${(e.progress * 100).floor()}%';
    final (glyph, label, tooltip) = switch (e.download?.transfer) {
      null => (
        Icon(
          Icons.devices_rounded,
          size: IconSizes.control,
          color: c.foregroundSecondary,
        ),
        'On ${e.device}',
        'Downloaded on ${e.device} · plays from there',
      ),
      final transfer => (
        DownloadRing(
          value: e.progress,
          glyph: Icons.devices_rounded,
          remote: true,
        ),
        'On ${e.device} $percent',
        switch (transfer) {
          PeerTransfer.queued => 'Waiting to download on ${e.device}',
          PeerTransfer.downloading => 'Downloading on ${e.device} · $percent',
          PeerTransfer.paused => 'Paused on ${e.device} · $percent',
          PeerTransfer.copying => 'Copying to ${e.device} · $percent',
        },
      ),
    };
    Widget trigger(VoidCallback onTap) => DownloadFace(
      glyph: glyph,
      label: label,
      tooltip: tooltip,
      labelled: labelled,
      onTap: onTap,
    );
    void showDownloads() =>
        ref.read(appDestinationProvider.notifier).go(AppDestination.downloads);
    if (!menu) {
      return trigger(e.finished ? () => ref.playElsewhere(e) : showDownloads);
    }
    return ActionMenu(
      actions: [
        if (e.finished) ...[
          MenuAction(
            'Play from ${e.device}',
            icon: Icons.play_arrow_rounded,
            onPressed: () => ref.playElsewhere(e),
          ),
          MenuAction(
            'Copy here from ${e.device}',
            icon: Icons.devices_rounded,
            onPressed: () => ref.copyHere(e),
          ),
        ] else
          MenuAction(
            'Show in Downloads',
            icon: Icons.downloading_rounded,
            onPressed: showDownloads,
          ),
        MenuAction(
          e.finished ? 'Download instead' : 'Download here too',
          icon: Icons.download_rounded,
          onPressed: () => ref.download(context, e.item, offerCopy: false),
        ),
      ],
      builder: (context, menu) =>
          trigger(() => menu.isOpen ? menu.close() : menu.open()),
    );
  }
}

/// A row's fact naming the paired device that has [id] while this one does
/// not, e.g. "On MacBook" or "On MacBook · 42%", so the row says so without
/// a tooltip. Null otherwise.
MetaItem? elsewhereFact(WidgetRef ref, String id) {
  if (ref.watch(offlineStateProvider(id)) is! NotDownloaded) return null;
  final e = ref.watch(elsewhereOfProvider(id));
  if (e == null) return null;
  return MetaItem(
    e.finished
        ? 'On ${e.device}'
        : 'On ${e.device} · ${(e.progress * 100).floor()}%',
    icon: Icons.devices_rounded,
  );
}
