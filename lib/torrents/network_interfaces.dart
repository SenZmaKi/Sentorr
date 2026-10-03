import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A device torrent traffic can be bound to.
typedef NetworkDevice = ({String name, String address, bool likelyVpn});

final _vpnName = RegExp(
  r'^(utun|tun|tap|wg|ppp|ipsec|proton|nord|mullvad|tailscale)',
  caseSensitive: false,
);

/// The machine's devices with an address, likely VPNs first. Re-read each
/// time it is watched afresh, since VPNs come and go.
final networkDevicesProvider = FutureProvider.autoDispose<List<NetworkDevice>>((
  ref,
) async {
  final interfaces = await NetworkInterface.list(includeLoopback: false);
  final devices = [
    for (final i in interfaces)
      if (i.addresses.isNotEmpty)
        (
          name: i.name,
          address: (i.addresses.firstWhere(
            (a) => a.type == InternetAddressType.IPv4,
            orElse: () => i.addresses.first,
          )).address,
          likelyVpn: _vpnName.hasMatch(i.name),
        ),
  ];
  devices.sort((a, b) {
    if (a.likelyVpn != b.likelyVpn) return a.likelyVpn ? -1 : 1;
    return a.name.compareTo(b.name);
  });
  return devices;
});
