import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/services.dart';
import '../../../../settings/notifier.dart';
import '../../../components/toggle.dart';
import '../../../../updates/controller.dart';
import '../../../../updates/models.dart';
import '../../../../updates/platform_installer.dart';
import '../../../../shared/source_directory/repository.dart';
import '../../../components/buttons.dart';
import '../settings_group.dart';

class UpdatesSection extends ConsumerWidget {
  const UpdatesSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updatesProvider);
    final controller = ref.read(updatesProvider.notifier);
    final directory = ref.watch(sourceDirectoryProvider);
    final busy = {
      UpdatePhase.checking,
      UpdatePhase.downloading,
      UpdatePhase.verifying,
      UpdatePhase.preparing,
      UpdatePhase.installing,
    }.contains(state.phase);
    final description = switch (state.phase) {
      UpdatePhase.checking => 'Checking for updates…',
      UpdatePhase.available =>
        '${state.release?.displayVersion ?? 'Update'} available',
      UpdatePhase.downloading =>
        'Downloading update${state.progress == null ? '' : ' · ${(state.progress! * 100).round()}%'}',
      UpdatePhase.verifying || UpdatePhase.preparing => 'Preparing update…',
      UpdatePhase.ready =>
        '${state.release?.displayVersion ?? 'Update'} ready to install',
      UpdatePhase.installing => 'Installing update…',
      UpdatePhase.failed => state.error ?? 'Update failed',
      UpdatePhase.unsupported => 'Updates are unavailable on this platform',
      UpdatePhase.idle =>
        'Updates download automatically while Sentorr is running',
    };
    return SettingsGroup(
      title: 'Updates',
      description: 'App releases and torrent source endpoints',
      children: [
        SettingsTile(
          title: 'Download updates automatically',
          subtitle: 'Prepare releases while Sentorr is running; install when you are ready',
          trailing: SToggle(
            value: ref.watch(settingsProvider).updates.automaticallyDownload,
            semanticLabel: 'Download updates automatically',
            onChanged: (value) => ref
                .read(settingsProvider.notifier)
                .update(
                  (s) => s.copyWith(
                    updates: s.updates.copyWith(automaticallyDownload: value),
                  ),
                ),
          ),
        ),
        SettingsTile(
          title: 'Sentorr ${state.currentVersion}',
          subtitle: description,
          keywords: 'version release install restart',
          trailing: SButton(
            label: state.phase == UpdatePhase.ready
                ? 'Install and restart'
                : state.phase == UpdatePhase.available
                ? 'Download update'
                : state.phase == UpdatePhase.failed
                ? 'Retry'
                : 'Check for updates',
            loading: busy,
            onPressed: busy
                ? null
                : () async {
                    if (state.phase == UpdatePhase.ready) {
                      await ref.read(prepareForUpdateProvider)();
                      final result = await controller.installAndRestart();
                      if (result == UpdateInstallDisposition.quitThenRelaunch ||
                          result ==
                              UpdateInstallDisposition
                                  .externalProcessWillTerminate) {
                        await ref.read(quitApplicationProvider)();
                      }
                    } else if (state.phase == UpdatePhase.available) {
                      await controller.download();
                    } else if (state.phase == UpdatePhase.failed) {
                      await controller.retry();
                    } else {
                      await controller.check();
                    }
                  },
          ),
        ),
        if (state.phase == UpdatePhase.downloading)
          SettingsTile(
            title: 'Download in progress',
            trailing: SButton(
              label: 'Cancel',
              onPressed: controller.cancelDownload,
            ),
          ),
        SettingsTile(
          title: 'Source directory',
          subtitle: directory.version == 0
              ? 'Built-in endpoints'
              : 'Directory version ${directory.version}',
          keywords: 'sources providers refresh',
          trailing: SButton(
            label: 'Refresh',
            onPressed: () =>
                ref.read(sourceDirectoryProvider.notifier).refresh(),
          ),
        ),
      ],
    );
  }
}
