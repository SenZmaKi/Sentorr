import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backup/drive/drive_config.dart';
import '../../../../backup/notifier.dart';
import '../../../../settings/models.dart';
import '../../../../settings/notifier.dart';
import '../../../components/buttons.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/title_format.dart';
import '../settings_controls.dart';
import '../settings_group.dart';

/// Keeping watch history safe: in a file, or on Google Drive.
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  /// What the last file action did, until the next one.
  String? _note;

  Future<void> _export() async {
    final saved = await ref.read(backupProvider.notifier).exportFile();
    if (mounted && saved) setState(() => _note = 'Saved the backup file');
  }

  Future<void> _import() async {
    final merged = await ref.read(backupProvider.notifier).importFile();
    if (mounted && merged) {
      setState(() => _note = 'Merged the backup into your history');
    }
  }

  @override
  Widget build(BuildContext context) {
    final backup = ref.watch(backupProvider);
    final notifier = ref.read(backupProvider.notifier);
    final c = context.colors;
    final minutes = ref.watch(
      settingsProvider.select((s) => s.backup.intervalMinutes),
    );
    return SettingsGroup(
      title: 'Backup',
      description:
          'Keeps your watch history and followed series, so another device '
          'picks up where you left off. Settings stay on each device, and '
          'downloaded files are not included. Restoring merges: the latest '
          'change to each wins',
      keywords: 'backup restore export import sync history google drive',
      children: [
        SettingsTile(
          icon: Icons.file_upload_outlined,
          title: 'Export to a file',
          subtitle: _note ?? 'Save a backup as a JSON file',
          keywords: 'save download',
          trailing: SButton(label: 'Export', onPressed: _export),
        ),
        SettingsTile(
          icon: Icons.file_download_outlined,
          title: 'Import from a file',
          subtitle: 'Merge a backup into this device',
          keywords: 'restore load',
          trailing: SButton(label: 'Import', onPressed: _import),
        ),
        // Release builds without the credentials simply leave Drive out; a
        // developer build says why it is missing.
        if (!driveConfigured && kDebugMode)
          const SettingsTile(
            icon: Icons.cloud_off_outlined,
            title: 'Google Drive',
            subtitle:
                'Not set up in this build. Run with '
                '--dart-define-from-file=dart_defines.local.json',
            keywords: 'cloud sync',
          ),
        if (driveConfigured)
          SettingsTile(
            icon: Icons.cloud_outlined,
            title: 'Google Drive',
            subtitle: backup.connected
                ? backup.lastBackup == null
                      ? 'Connected'
                      : 'Backed up ${relativeDay(backup.lastBackup!)}'
                : 'Back up automatically to a private Sentorr folder in '
                      'your Drive',
            keywords: 'cloud sync',
            below: backup.error == null
                ? null
                : Text(
                    backup.error!,
                    style: context.type.caption.copyWith(color: c.error),
                  ),
            trailing: backup.connected
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SButton(
                        label: 'Back up now',
                        loading: backup.busy,
                        onPressed: backup.busy ? null : notifier.syncNow,
                      ),
                      const SizedBox(width: Space.s8),
                      SButton.ghost(
                        label: 'Disconnect',
                        onPressed: backup.busy ? null : notifier.disconnect,
                      ),
                    ],
                  )
                : SButton(
                    label: 'Connect',
                    loading: backup.busy,
                    onPressed: backup.busy ? null : notifier.connect,
                  ),
          ),
        if (driveConfigured)
          SettingsTile(
            icon: Icons.schedule_rounded,
            title: 'Back up every',
            subtitle:
                'Also when you leave the app and when you come back to it',
            keywords: 'interval frequency automatic hourly',
            trailing: ChoiceField<int>(
              value: BackupSettings.intervalOptions.contains(minutes)
                  ? minutes
                  : BackupSettings.defaultIntervalMinutes,
              options: BackupSettings.intervalOptions,
              labelOf: _intervalLabel,
              semanticLabel: 'Back up every',
              onChanged: (value) => ref
                  .read(settingsProvider.notifier)
                  .update(
                    (s) => s.copyWith(
                      backup: s.backup.copyWith(intervalMinutes: value),
                    ),
                  ),
            ),
          ),
      ],
    );
  }
}

String _intervalLabel(int minutes) => minutes < 60
    ? '$minutes minutes'
    : minutes == 60
    ? '1 hour'
    : '${minutes ~/ 60} hours';
