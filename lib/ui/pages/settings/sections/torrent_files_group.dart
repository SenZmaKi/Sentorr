import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../player/session.dart';
import '../../../../player/stream/session_config.dart';
import '../../../../settings/models.dart';
import '../../../components/buttons.dart';
import '../../../components/confirm_dialog.dart';
import '../../../shared/open_folder.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/title_format.dart';
import '../settings_controls.dart';
import '../settings_group.dart';
import '../settings_search.dart';

typedef StreamingEdit = void Function(
  StreamingSettings Function(StreamingSettings) change,
);

/// Where torrents are saved, how many stay after watching, and the space
/// they take, together.
class TorrentFilesGroup extends StatelessWidget {
  const TorrentFilesGroup({
    super.key,
    required this.settings,
    required this.edit,
  });

  final StreamingSettings settings;
  final StreamingEdit edit;

  @override
  Widget build(BuildContext context) {
    final keep = settings.keepRecentTorrents;
    return SettingsGroup(
      title: 'Torrent files',
      description: 'Where downloads live and how long they stay',
      children: [
        _FolderTile(custom: settings.torrentDirectory != null, edit: edit),
        SettingsTile(
          icon: Icons.history_toggle_off_rounded,
          title: 'Keep recent torrents',
          subtitle: keep == 0
              ? 'Each torrent is deleted when playback ends'
              : 'Watching one again starts from what was downloaded; '
                    'older ones are deleted',
          keywords: 'lru cache reuse',
          trailing: LimitField(
            value: keep,
            presets: const {0: 'Off'},
            customDefault: 3,
            min: 1,
            max: StreamingSettings.maxKeptTorrents,
            unit: 'torrents',
            semanticLabel: 'Keep recent torrents',
            onChanged: (n) => edit((s) => s.copyWith(keepRecentTorrents: n)),
          ),
        ),
        const _KeptTile(),
      ],
    );
  }
}

class _FolderTile extends ConsumerWidget implements SettingsSearchable {
  const _FolderTile({required this.custom, required this.edit});

  final bool custom;
  final StreamingEdit edit;

  static const _title = 'Torrent folder';
  static const _keywords = 'download location directory path save';

  @override
  bool matches(String? query) => settingsMatch(query, [_title, _keywords]);

  Future<void> _choose() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose where torrents are saved',
    );
    if (path != null) edit((s) => s.copyWith(torrentDirectory: path));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(torrentDirectoryProvider);
    return SettingsTile(
      icon: Icons.folder_outlined,
      title: _title,
      subtitle: custom ? 'Your folder' : 'Sentorr\'s own folder',
      trailing: Wrap(
        spacing: Space.s8,
        runSpacing: Space.s8,
        children: [
          SButton(label: 'Open', onPressed: () => openFolder(path)),
          SButton(label: 'Change', onPressed: _choose),
          if (custom)
            SButton.ghost(
              label: 'Reset',
              onPressed: () =>
                  edit((s) => s.copyWith(resetTorrentDirectory: true)),
            ),
        ],
      ),
      below: Text(
        path,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.type.technical.copyWith(
          color: context.colors.foregroundMuted,
        ),
      ),
    );
  }
}

/// Space kept torrents take, and a way to free it.
class _KeptTile extends ConsumerWidget implements SettingsSearchable {
  const _KeptTile();

  static const _title = 'Kept torrents';
  static const _keywords = 'clear delete space disk cache';

  @override
  bool matches(String? query) => settingsMatch(query, [_title, _keywords]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(playerSessionProvider.select((s) => s != null));
    final size = ref.watch(keptTorrentsSizeProvider);
    return SettingsTile(
      icon: Icons.folder_delete_outlined,
      title: _title,
      subtitle: playing
          ? 'Close the player to clear torrents'
          : size.when(
              data: (bytes) => '${sizeLabel(bytes)} on disk',
              loading: () => 'Measuring…',
              error: (_, _) => 'Size unknown',
            ),
      trailing: SButton(
        label: 'Clear',
        onPressed: playing
            ? null
            : () async {
                final ok = await confirm(
                  context,
                  title: 'Clear kept torrents?',
                  message:
                      'Downloaded torrent files are deleted. Other files in '
                      'your torrent folder are left alone.',
                  confirmLabel: 'Clear',
                );
                if (!ok) return;
                await ref
                    .read(torrentCacheProvider)
                    .clear(ref.read(torrentRootsProvider));
                ref.invalidate(keptTorrentsSizeProvider);
              },
      ),
    );
  }
}
