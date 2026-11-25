import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../settings/models.dart';
import '../../../../settings/notifier.dart';
import '../../../../smart_downloads/controller.dart';
import '../../../components/buttons.dart';
import '../../../components/toggle.dart';
import '../settings_controls.dart';
import '../settings_group.dart';

/// Whether Sentorr keeps a reserve of unwatched content to watch offline,
/// and how much.
class SmartDownloadGroup extends ConsumerWidget {
  const SmartDownloadGroup({super.key});

  static const _targets = [60, 120, 180, 300, 480, 720];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider.select((s) => s.smart));
    void edit(SmartDownloadSettings Function(SmartDownloadSettings) change) =>
        ref
            .read(settingsProvider.notifier)
            .update((a) => a.copyWith(smart: change(a.smart)));
    return SettingsGroup(
      title: 'Smart downloads',
      description:
          'Keeps something unwatched ready offline: what you are partway '
          'through, the next episodes of your series and movies like ones '
          'you finished. Watched ones are deleted and replaced.',
      keywords: 'smart offline reserve automatic recommendations',
      children: [
        SettingsTile(
          icon: Icons.auto_awesome_outlined,
          title: 'Smart downloads',
          subtitle: s.enabled
              ? 'Waits while you watch and while your own downloads run'
              : 'Off; turning it off keeps what finished downloading',
          keywords: 'enable smart',
          trailing: SToggle(
            value: s.enabled,
            semanticLabel: 'Smart downloads',
            onChanged: (v) => edit((s) => s.copyWith(enabled: v)),
          ),
        ),
        SettingsTile(
          icon: Icons.schedule_rounded,
          title: 'Keep ready',
          subtitle: 'Unwatched watch time to have downloaded',
          keywords: 'target hours runtime reserve',
          enabled: s.enabled,
          trailing: ChoiceField<int>(
            value: _targets.contains(s.targetMinutes) ? s.targetMinutes : 180,
            options: _targets,
            labelOf: (m) => m == 60 ? '1 hour' : '${m ~/ 60} hours',
            semanticLabel: 'Keep ready',
            onChanged: (m) => edit((s) => s.copyWith(targetMinutes: m)),
          ),
        ),
        SettingsTile(
          icon: Icons.delete_sweep_outlined,
          title: 'Clear smart downloads',
          subtitle: 'Deletes them; ones you chose to keep stay',
          keywords: 'remove delete reset',
          trailing: SButton(
            label: 'Clear',
            onPressed: () => ref.read(smartDownloadsProvider).clear(),
          ),
        ),
      ],
    );
  }
}
