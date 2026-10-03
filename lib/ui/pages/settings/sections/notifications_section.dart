import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../notifications/notification_service.dart';
import '../../../../settings/models.dart';
import '../../../../settings/notifier.dart';
import '../../../components/toggle.dart';
import '../settings_group.dart';

class NotificationsSection extends ConsumerWidget {
  const NotificationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(settingsProvider.select((s) => s.notifications));
    Future<void> edit(
      bool on,
      NotificationSettings Function(NotificationSettings) change,
    ) async {
      // Turning one on is when the system should ask, not at a surprise.
      if (on) await ref.read(notificationServiceProvider).requestPermission();
      await ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(notifications: change(s.notifications)));
    }

    return SettingsGroup(
      title: 'Notifications',
      description: 'Shown by your system while Sentorr is running',
      children: [
        SettingsTile(
          icon: Icons.notifications_outlined,
          title: 'Allow notifications',
          subtitle: 'Turn off to silence everything below',
          keywords: 'mute silence',
          trailing: SToggle(
            value: n.enabled,
            semanticLabel: 'Allow notifications',
            onChanged: (v) => edit(v, (n) => n.copyWith(enabled: v)),
          ),
        ),
        SettingsTile(
          icon: Icons.new_releases_outlined,
          title: 'New episodes',
          subtitle: 'When an episode airs for a series you have caught up on',
          keywords: 'series following airing released',
          enabled: n.enabled,
          trailing: SToggle(
            value: n.newEpisodes,
            semanticLabel: 'New episode notifications',
            onChanged: n.enabled
                ? (v) => edit(v, (n) => n.copyWith(newEpisodes: v))
                : null,
          ),
        ),
        SettingsTile(
          icon: Icons.download_done_rounded,
          title: 'Downloads ready',
          subtitle: 'When a download or season finishes, or a download fails',
          keywords: 'auto download finished complete failed offline',
          enabled: n.enabled,
          trailing: SToggle(
            value: n.downloadsReady,
            semanticLabel: 'Download ready notifications',
            onChanged: n.enabled
                ? (v) => edit(v, (n) => n.copyWith(downloadsReady: v))
                : null,
          ),
        ),
      ],
    );
  }
}
