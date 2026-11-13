import 'package:flutter/material.dart';

import '../../player/stream/reusable_torrent.dart';
import '../../torrents/filters.dart';
import '../components/adaptive_sheet.dart';
import '../components/buttons.dart';
import '../components/dialog_actions.dart';
import 'theme/theme.dart';

enum StreamDownloadChoice { save, search }

Future<StreamDownloadChoice?> askToSaveStream(
  BuildContext context,
  ReusableTorrent torrent, {
  required bool playing,
  required String item,
}) => showAdaptiveSheet<StreamDownloadChoice>(
  context,
  maxWidth: 480,
  builder: (context) {
    final colors = context.colors;
    final type = context.type;
    final release = torrent.release;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            playing ? 'Download the playing file?' : 'Save the cached file?',
            style: type.title.copyWith(color: colors.foreground),
          ),
          const SizedBox(height: Space.s8),
          Text(
            playing
                ? 'Save $item to Downloads and fetch the rest of the file '
                      'beyond the playback buffer.'
                : 'Move the cached data for $item to Downloads and fetch '
                      'any missing pieces.',
            style: type.body.copyWith(color: colors.foregroundSecondary),
          ),
          const SizedBox(height: Space.s16),
          Text(
            release.name,
            style: type.body.copyWith(color: colors.foreground),
          ),
          Text(
            [
              release.source.label,
              if (release.resolution case final height?) '${height}p',
              if (torrent.size >= 1024 * 1024 * 1024)
                '${(torrent.size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB'
              else
                '${(torrent.size / (1024 * 1024)).toStringAsFixed(1)} MiB',
            ].join(' · '),
            style: type.bodySmall.copyWith(color: colors.foregroundSecondary),
          ),
          const SizedBox(height: Space.s24),
          DialogActions(
            children: [
              SButton.ghost(
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
              SButton(
                label: 'Search torrents',
                onPressed: () =>
                    Navigator.pop(context, StreamDownloadChoice.search),
              ),
              SButton.primary(
                label: playing ? 'Download full file' : 'Save to Downloads',
                onPressed: () =>
                    Navigator.pop(context, StreamDownloadChoice.save),
              ),
            ],
          ),
        ],
      ),
    );
  },
);
