import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../../../settings/models.dart';
import '../../../../settings/notifier.dart';
import '../../../../torrents/network_interfaces.dart';
import '../../../components/buttons.dart';
import '../../../shared/theme/theme.dart';
import '../settings_controls.dart';
import '../settings_group.dart';
import '../settings_validation.dart';
import '../text_setting_field.dart';

/// The proxy and VPN interface all torrent traffic goes through.
class TrafficRouteGroup extends ConsumerWidget {
  const TrafficRouteGroup({super.key});

  static const _kindLabels = {
    TorrentProxyKind.none: 'None',
    TorrentProxyKind.socks5: 'SOCKS5',
    TorrentProxyKind.socks4: 'SOCKS4',
    TorrentProxyKind.http: 'HTTP',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(settingsProvider.select((s) => s.network));
    final proxy = n.proxy;
    final notifier = ref.read(settingsProvider.notifier);
    void edit(NetworkSettings Function(NetworkSettings) change) =>
        notifier.update((a) => a.copyWith(network: change(a.network)));
    void editProxy(ProxySettings Function(ProxySettings) change) =>
        edit((n) => n.copyWith(proxy: change(n.proxy)));
    return SettingsGroup(
      title: 'Proxy and VPN',
      description: 'Route torrent traffic; catalog and search are unaffected',
      children: [
        SettingsTile(
          icon: Icons.vpn_lock_outlined,
          title: 'VPN interface',
          subtitle: n.networkInterface == null
              ? 'Torrents use any connection'
              : 'Torrents stop while ${n.networkInterface} is down',
          keywords: 'vpn interface bind kill switch leak network adapter',
          trailing: _DevicePicker(
            selected: n.networkInterface,
            onChanged: (name) => edit(
              (n) => name == null
                  ? n.copyWith(anyInterface: true)
                  : n.copyWith(networkInterface: name),
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.shield_outlined,
          title: 'Proxy',
          subtitle: proxy.enabled
              ? 'Torrents stop while the proxy is unreachable'
              : 'Connect to peers directly',
          keywords: 'proxy socks socks5 socks4 http vpn',
          trailing: ChoiceField<TorrentProxyKind>(
            value: proxy.kind,
            options: TorrentProxyKind.values,
            labelOf: (k) => _kindLabels[k]!,
            semanticLabel: 'Proxy type',
            onChanged: (k) => editProxy((p) => p.copyWith(kind: k)),
          ),
        ),
        if (proxy.enabled) ...[
          SettingsTile(
            icon: Icons.dns_outlined,
            title: 'Proxy host',
            subtitle: 'Hostname or IP address',
            keywords: 'proxy server address',
            trailing: TextSettingField(
              value: proxy.host,
              hint: '127.0.0.1',
              semanticLabel: 'Proxy host',
              validator: validateProxyHost,
              onSubmitted: (v) => editProxy((p) => p.copyWith(host: v)),
            ),
          ),
          SettingsTile(
            icon: Icons.numbers_rounded,
            title: 'Proxy port',
            keywords: 'proxy port',
            trailing: NumberField(
              value: proxy.port,
              min: 1,
              max: 65535,
              unit: 'port',
              semanticLabel: 'Proxy port',
              onSubmitted: (v) => editProxy((p) => p.copyWith(port: v)),
            ),
          ),
          SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Proxy username',
            subtitle: 'Leave blank if the proxy needs no login',
            keywords: 'proxy login authentication user',
            trailing: TextSettingField(
              value: proxy.username,
              semanticLabel: 'Proxy username',
              onSubmitted: (v) => editProxy((p) => p.copyWith(username: v)),
            ),
          ),
          if (proxy.kind != TorrentProxyKind.socks4)
            SettingsTile(
              icon: Icons.key_outlined,
              title: 'Proxy password',
              subtitle: 'Kept in the system keychain',
              keywords: 'proxy login authentication password',
              trailing: TextSettingField(
                value: proxy.password,
                obscureText: true,
                semanticLabel: 'Proxy password',
                onSubmitted: (v) => editProxy((p) => p.copyWith(password: v)),
              ),
            ),
        ],
      ],
    );
  }
}

/// Any interface, or one of the machine's; a saved one that is down stays
/// listed so it can be seen and changed.
class _DevicePicker extends ConsumerWidget {
  const _DevicePicker({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(networkDevicesProvider).value ?? const [];
    final byName = {for (final d in devices) d.name: d};
    final options = <String?>[
      null,
      ...byName.keys,
      if (selected != null && !byName.containsKey(selected)) selected,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Find interfaces again',
          onPressed: () => ref.invalidate(networkDevicesProvider),
        ),
        const SizedBox(width: Space.s8),
        ChoiceField<String?>(
          value: selected,
          options: options,
          labelOf: (name) {
            if (name == null) return 'Any';
            final device = byName[name];
            return device == null ? '$name (down)' : name;
          },
          semanticLabel: 'VPN interface',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
