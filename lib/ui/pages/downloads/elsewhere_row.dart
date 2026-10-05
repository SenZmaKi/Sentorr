import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/elsewhere.dart';
import '../../../sync/payload.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/progress_track.dart';
import '../../shared/download_actions.dart';
import '../../shared/play_route.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'row_frame.dart';
import 'transfer_stats.dart';

/// An item on a paired device and not on this one, as a Downloads row. It
/// plays on tap, from that device once finished there; a finished one can
/// be copied here, and one still on its way downloaded here too.
class ElsewhereRow extends ConsumerWidget {
  const ElsewhereRow(this.held, {super.key, this.compact = false});

  final Elsewhere held;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = held;
    return DownloadRowFrame(
      item: e.item,
      status: _status(e),
      facts: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TransferStats([
            if (e.size > 0)
              MetaItem(
                e.finished
                    ? sizeLabel(e.size)
                    : '${sizeLabel((e.size * e.progress).round())} of '
                          '${sizeLabel(e.size)}',
                technical: true,
              ),
          ]),
          if (!e.finished) ...[
            const SizedBox(height: Space.s8),
            ProgressTrack.value(e.progress),
          ],
        ],
      ),
      onTap: () =>
          e.finished ? ref.playElsewhere(e) : ref.playItem(e.item),
      actions: [
        if (e.finished)
          SIconButton(
            icon: Icons.download_rounded,
            tooltip: 'Copy here from ${e.device}',
            onPressed: () => ref.copyHere(e),
          )
        else
          SIconButton(
            icon: Icons.download_rounded,
            tooltip: 'Download here too',
            onPressed: () => ref.download(context, e.item, offerCopy: false),
          ),
      ],
      compact: compact,
    );
  }

  static RowStatus _status(Elsewhere e) {
    final on = e.device, percent = '${(e.progress * 100).floor()}%';
    return switch (e.download?.transfer) {
      null => (Icons.devices_rounded, 'Downloaded on $on', RowTone.success),
      PeerTransfer.queued => (
        Icons.schedule_rounded,
        'Queued on $on',
        RowTone.neutral,
      ),
      PeerTransfer.paused => (
        Icons.pause_rounded,
        'Paused on $on at $percent',
        RowTone.neutral,
      ),
      PeerTransfer.downloading => (
        Icons.downloading_rounded,
        'Downloading on $on $percent',
        RowTone.info,
      ),
      PeerTransfer.copying => (
        Icons.devices_rounded,
        'Copying to $on $percent',
        RowTone.info,
      ),
    };
  }
}
