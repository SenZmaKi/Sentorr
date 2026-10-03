import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../downloads/models.dart';
import '../../../../library/notifier.dart';
import '../../../../settings/models.dart';
import '../../../../settings/notifier.dart';
import '../../../components/buttons.dart';
import '../../../components/toggle.dart';
import '../../../shared/open_folder.dart';
import '../../../shared/theme/theme.dart';
import '../settings_controls.dart';
import '../settings_group.dart';
import 'auto_download_group.dart';

typedef _Edit = void Function(
  DownloadPreferences Function(DownloadPreferences) change,
);

class DownloadsSection extends ConsumerWidget {
  const DownloadsSection({super.key});

  static const _ratios = [0.5, 1.0, 2.0, 3.0, 5.0];
  static const _minutes = [15, 30, 60, 180, 720, 1440];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(settingsProvider.select((s) => s.downloads));
    final notifier = ref.read(settingsProvider.notifier);
    void edit(DownloadPreferences Function(DownloadPreferences) change) =>
        notifier.update((a) => a.copyWith(downloads: change(a.downloads)));
    final limited = d.seeding == SeedingMode.limited;
    return Column(
      children: [
        SettingsGroup(
          title: 'Downloads',
          description: 'Movies and episodes saved to watch offline',
          keywords: 'offline save',
          children: [
            _FolderTile(custom: d.directory != null, edit: edit),
            SettingsTile(
              icon: Icons.download_rounded,
              title: 'Simultaneous downloads',
              subtitle: 'The rest wait in order on the Downloads page',
              keywords: 'queue parallel active concurrent',
              trailing: NumberField(
                value: d.maxActive,
                min: 1,
                max: DownloadPreferences.maxSlots,
                unit: 'at once',
                semanticLabel: 'Simultaneous downloads',
                onSubmitted: (n) => edit((d) => d.copyWith(maxActive: n)),
              ),
            ),
            SettingsTile(
              icon: Icons.pause_circle_outline_rounded,
              title: 'Pause downloads while watching',
              subtitle:
                  'Leaves the bandwidth to playback; what you watch keeps '
                  'downloading',
              keywords: 'bandwidth streaming playback priority',
              trailing: SToggle(
                value: d.pauseWhileStreaming,
                semanticLabel: 'Pause downloads while watching',
                onChanged: (v) =>
                    edit((d) => d.copyWith(pauseWhileStreaming: v)),
              ),
            ),
          ],
        ),
        const AutoDownloadGroup(),
        SettingsGroup(
          title: 'Sharing',
          description: 'Seeding finished downloads back to others',
          children: [
            SettingsTile(
              icon: Icons.upload_rounded,
              title: 'Share after downloading',
              subtitle: switch (d.seeding) {
                SeedingMode.disabled => 'Each download stops when it finishes',
                SeedingMode.limited =>
                  'Until both the amount and the time below are reached',
                SeedingMode.indefinitely => 'Until you delete the download',
              },
              keywords: 'seed seeding ratio upload',
              trailing: ChoiceField<SeedingMode>(
                value: d.seeding,
                options: SeedingMode.values,
                labelOf: (m) => switch (m) {
                  SeedingMode.disabled => 'Off',
                  SeedingMode.limited => 'For a while',
                  SeedingMode.indefinitely => 'Always',
                },
                semanticLabel: 'Share after downloading',
                onChanged: (m) => edit((d) => d.copyWith(seeding: m)),
              ),
            ),
            SettingsTile(
              icon: Icons.balance_rounded,
              title: 'Share at least',
              subtitle: 'Uploaded, as a multiple of the download',
              keywords: 'ratio seed',
              enabled: limited,
              trailing: ChoiceField<double>(
                value: _ratios.contains(d.seedRatio) ? d.seedRatio : 1,
                options: _ratios,
                labelOf: (r) => '${r == r.roundToDouble() ? r.round() : r}×',
                semanticLabel: 'Share at least',
                onChanged: (r) => edit((d) => d.copyWith(seedRatio: r)),
              ),
            ),
            SettingsTile(
              icon: Icons.timer_outlined,
              title: 'Share for at least',
              keywords: 'seed time minutes hours',
              enabled: limited,
              trailing: ChoiceField<int>(
                value: _minutes.contains(d.seedMinutes) ? d.seedMinutes : 30,
                options: _minutes,
                labelOf: (m) => m < 60
                    ? '$m minutes'
                    : m == 60
                    ? '1 hour'
                    : '${m ~/ 60} hours',
                semanticLabel: 'Share for at least',
                onChanged: (m) => edit((d) => d.copyWith(seedMinutes: m)),
              ),
            ),
            SettingsTile(
              icon: Icons.cloud_upload_outlined,
              title: 'Simultaneous shares',
              keywords: 'seeds active',
              enabled: d.seeding != SeedingMode.disabled,
              trailing: NumberField(
                value: d.maxSeeds,
                min: 1,
                max: DownloadPreferences.maxSlots,
                unit: 'at once',
                semanticLabel: 'Simultaneous shares',
                onSubmitted: (n) => edit((d) => d.copyWith(maxSeeds: n)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FolderTile extends ConsumerWidget {
  const _FolderTile({required this.custom, required this.edit});

  final bool custom;
  final _Edit edit;

  Future<void> _choose() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose where downloads are saved',
    );
    if (path != null) edit((d) => d.copyWith(directory: path));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(downloadsDirectoryProvider);
    return SettingsTile(
      icon: Icons.folder_outlined,
      title: 'Download folder',
      subtitle: custom
          ? 'Your folder; downloads already made stay where they are'
          : 'A Sentorr folder in your downloads',
      keywords: 'location directory path save',
      trailing: Wrap(
        spacing: Space.s8,
        runSpacing: Space.s8,
        children: [
          SButton(label: 'Open', onPressed: () => openFolder(path)),
          SButton(label: 'Change', onPressed: _choose),
          if (custom)
            SButton.ghost(
              label: 'Reset',
              onPressed: () => edit((d) => d.copyWith(resetDirectory: true)),
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
