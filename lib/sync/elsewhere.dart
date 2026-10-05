import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/models.dart';
import 'devices.dart';
import 'payload.dart';
import 'peers.dart';

/// A movie or episode on a reachable paired device: finished there, so it
/// streams or copies from it, or still on its way.
class Elsewhere {
  Elsewhere.finished(this.deviceId, this.device, PeerMedia this.media)
    : item = media.item,
      download = null;

  Elsewhere.coming(this.deviceId, this.device, PeerDownload this.download)
    : item = download.item,
      media = null;

  final String deviceId;

  /// The device's name.
  final String device;
  final PlaybackItem item;

  /// Its finished file; null while [download] runs.
  final PeerMedia? media;
  final PeerDownload? download;

  bool get finished => media != null;
  double get progress => download?.progress ?? 1;

  /// Bytes; 0 while a download's size is unknown.
  int get size => media?.size ?? download?.size ?? 0;

  /// Whole percent, as it is shown.
  int get _percent => (progress * 100).floor();

  /// Equal while it looks the same, so a button does not rebuild for every
  /// byte another device receives.
  @override
  bool operator ==(Object other) =>
      other is Elsewhere &&
      other.deviceId == deviceId &&
      other.item.id == item.id &&
      other.download?.transfer == download?.transfer &&
      other._percent == _percent;

  @override
  int get hashCode =>
      Object.hash(deviceId, item.id, download?.transfer, _percent);
}

/// One reachable paired device and what it holds: finished items first,
/// then those on their way.
typedef DeviceHoldings = ({String id, String name, List<Elsewhere> items});

/// What each reachable paired device holds, in the order playback prefers
/// them.
final elsewhereProvider = Provider<List<DeviceHoldings>>((ref) {
  final devices = ref.watch(devicesProvider);
  return [
    for (final MapEntry(key: id, value: peer)
        in ref.watch(peersProvider).entries)
      if (devices.byId(id) case final device? when peer.online)
        (
          id: id,
          name: device.name,
          items: [
            for (final m in peer.media) Elsewhere.finished(id, device.name, m),
            for (final d in peer.downloads)
              if (!peer.media.any((m) => m.id == d.id))
                Elsewhere.coming(id, device.name, d),
          ],
        ),
  ];
});

/// Where item [id] is on paired devices: the first that has it finished,
/// which is where it would play from, otherwise the furthest along.
final elsewhereOfProvider = Provider.family<Elsewhere?, String>((ref, id) {
  Elsewhere? best;
  for (final device in ref.watch(elsewhereProvider)) {
    for (final e in device.items) {
      if (e.item.id != id) continue;
      if (e.finished) return e;
      if (best == null || e.progress > best.progress) best = e;
    }
  }
  return best;
});
