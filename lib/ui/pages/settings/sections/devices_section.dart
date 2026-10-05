import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../sync/devices.dart';
import '../../../../sync/models.dart';
import '../../../../sync/peers.dart';
import '../../../../sync/service.dart';
import '../../../components/buttons.dart';
import '../../../components/confirm_dialog.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/title_format.dart';
import '../settings_group.dart';
import '../text_setting_field.dart';
import 'pairing_sheet.dart';

/// "Online · 12 downloads to stream", "Synced Yesterday" or why it could
/// not be reached.
String _statusLine(PairedDevice device, PeerStatus? peer) {
  if (peer?.syncing == true) return 'Syncing…';
  if (peer?.online == true) {
    final count = peer!.media.length;
    return count == 0
        ? 'Online'
        : 'Online · $count download${count == 1 ? '' : 's'} to stream';
  }
  final synced = device.syncedAt;
  return synced == null
      ? 'Not reachable yet'
      : 'Not reachable · synced ${relativeDay(synced).toLowerCase()}';
}

/// This device's name and the devices it syncs and streams with.
class DevicesSection extends ConsumerWidget {
  const DevicesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    final peers = ref.watch(peersProvider);
    final notifier = ref.read(devicesProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: 'This device',
          description: 'How your other devices list this one',
          keywords: 'name sync pair',
          children: [
            SettingsTile(
              icon: Icons.badge_outlined,
              title: 'Name',
              keywords: 'rename device',
              trailing: TextSettingField(
                value: devices.identity.name,
                semanticLabel: 'Device name',
                onSubmitted: notifier.rename,
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: 'Paired devices',
          description:
              'Paired devices on the same network share watch progress and '
              'followed series, and stream each other’s downloads',
          keywords: 'sync pair stream devices network',
          children: [
            if (devices.paired.isEmpty)
              const SettingsTile(
                icon: Icons.devices_other_rounded,
                title: 'No devices yet',
                subtitle: 'Pair a phone, laptop or tablet running Sentorr',
              ),
            for (final d in devices.paired)
              _DeviceTile(device: d, peer: peers[d.id]),
            SettingsTile(
              icon: Icons.add_link_rounded,
              title: 'Pair a device',
              subtitle: 'Confirm the same code on both devices',
              keywords: 'add connect link',
              trailing: SButton(
                label: 'Pair',
                onPressed: () => showPairingSheet(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.device, this.peer});

  final PairedDevice device;
  final PeerStatus? peer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing = peer?.syncing == true;
    return SettingsTile(
      icon: Icons.devices_rounded,
      title: device.name,
      subtitle: _statusLine(device, peer),
      below: peer?.online == true || peer?.error == null
          ? null
          : Text(
              peer!.error!,
              style: context.type.caption.copyWith(
                color: context.colors.foregroundMuted,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Space.s8,
        children: [
          SIconButton(
            icon: Icons.sync_rounded,
            tooltip: 'Sync now',
            onPressed: syncing
                ? null
                : () => ref.read(peersProvider.notifier).syncWith(device.id),
          ),
          SIconButton(
            icon: Icons.link_off_rounded,
            tooltip: 'Unpair',
            onPressed: () async {
              final sure = await confirm(
                context,
                title: 'Unpair ${device.name}?',
                message:
                    'They stop syncing and streaming to each other. What '
                    'already synced stays on both.',
                confirmLabel: 'Unpair',
              );
              if (sure) {
                await ref.read(syncServiceProvider).unpair(device.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
