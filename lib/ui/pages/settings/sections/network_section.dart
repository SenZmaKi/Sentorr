import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../settings/models.dart';
import '../../../../settings/notifier.dart';
import '../../../components/toggle.dart';
import '../settings_controls.dart';
import '../settings_group.dart';
import 'traffic_route_group.dart';

/// The one torrent session's limits and discovery: streams and downloads
/// share them, and changes apply at once.
class NetworkSection extends ConsumerWidget {
  const NetworkSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(settingsProvider.select((s) => s.network));
    final notifier = ref.read(settingsProvider.notifier);
    void edit(NetworkSettings Function(NetworkSettings) change) =>
        notifier.update((a) => a.copyWith(network: change(a.network)));
    int mb(int bytes) => (bytes / megabyte).round();
    Widget toggle(
      String label,
      bool value,
      NetworkSettings Function(bool) on,
    ) => SToggle(
      value: value,
      semanticLabel: label,
      onChanged: (v) => edit((_) => on(v)),
    );
    return Column(
      children: [
        SettingsGroup(
          title: 'Speed',
          description: 'Shared by streams and downloads; applies at once',
          children: [
            SettingsTile(
              icon: Icons.arrow_downward_rounded,
              title: 'Download limit',
              subtitle: 'Peers on your own network are not limited',
              keywords: 'speed bandwidth throttle',
              trailing: LimitField(
                value: mb(n.downloadLimitBytesPerSecond),
                presets: const {0: 'Unlimited'},
                customDefault: 10,
                min: 1,
                unit: 'MB/s',
                semanticLabel: 'Download limit',
                onChanged: (v) => edit(
                  (n) => n.copyWith(downloadLimitBytesPerSecond: v * megabyte),
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.arrow_upward_rounded,
              title: 'Upload limit',
              subtitle: 'What you share back while torrents run',
              keywords: 'speed bandwidth seeding share',
              trailing: LimitField(
                value: mb(n.uploadLimitBytesPerSecond),
                presets: const {0: 'Unlimited'},
                customDefault: 2,
                min: 1,
                unit: 'MB/s',
                semanticLabel: 'Upload limit',
                onChanged: (v) => edit(
                  (n) => n.copyWith(uploadLimitBytesPerSecond: v * megabyte),
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.lan_outlined,
              title: 'Connections',
              subtitle: 'Most peers connected at once, across all torrents',
              keywords: 'peers sockets limit',
              trailing: NumberField(
                value: n.maxConnections,
                min: 10,
                max: 2000,
                unit: 'peers',
                semanticLabel: 'Most connections',
                onSubmitted: (v) => edit((n) => n.copyWith(maxConnections: v)),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: 'Finding peers',
          description: 'Ways Sentorr reaches people sharing a torrent',
          children: [
            SettingsTile(
              icon: Icons.hub_outlined,
              title: 'Connect over uTP',
              subtitle: 'Reach more peers, including those behind routers',
              keywords: 'transport utp tcp peers',
              trailing: toggle(
                'Connect over uTP',
                n.utp,
                (v) => n.copyWith(utp: v),
              ),
            ),
            SettingsTile(
              icon: Icons.public_rounded,
              title: 'Distributed hash table',
              subtitle: 'Find peers without a tracker',
              keywords: 'dht trackerless discovery',
              trailing: toggle('DHT', n.dht, (v) => n.copyWith(dht: v)),
            ),
            SettingsTile(
              icon: Icons.router_outlined,
              title: 'Local network',
              subtitle: 'Find peers on the same network',
              keywords: 'lsd local service discovery lan',
              trailing: toggle(
                'Local peer discovery',
                n.lsd,
                (v) => n.copyWith(lsd: v),
              ),
            ),
            SettingsTile(
              icon: Icons.settings_ethernet_rounded,
              title: 'Open a port on the router',
              subtitle: 'Lets peers connect to you, through UPnP and NAT-PMP',
              keywords: 'upnp nat pmp port forwarding incoming',
              trailing: toggle(
                'Open a port on the router',
                n.upnp && n.natPmp,
                (v) => n.copyWith(upnp: v, natPmp: v),
              ),
            ),
          ],
        ),
        const TrafficRouteGroup(),
      ],
    );
  }
}
