import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/models.dart';
import '../player/stream/offline_source.dart';
import 'devices.dart';
import 'peer_file.dart';
import 'peer_status.dart';
import 'service.dart';

OfflineSource? sharedPeerSource(
  Ref ref,
  Map<String, PeerStatus> peers,
  PlaybackItem item, {
  Set<Uri> excluded = const {},
}) {
  final devices = ref.read(devicesProvider);
  for (final MapEntry(key: id, value: peer) in peers.entries) {
    if (!peer.online || !peer.media.any((m) => m.id == item.id)) continue;
    final media = peer.media.firstWhere((m) => m.id == item.id);
    final name = devices.byId(id)?.name;
    final source = name == null
        ? null
        : peerFileForOffer(ref.read(syncServiceProvider), id, name, media);
    if (source != null && !excluded.contains(source.url)) return source;
  }
  final candidates = [
    for (final entry in peers.entries)
      if (entry.value.online)
        for (final stream in entry.value.streams)
          if (stream.id == item.id && (stream.bufferedBytes ?? 0) > 0)
            (id: entry.key, stream: stream),
  ]..sort((a, b) => b.stream.bufferedBytes!.compareTo(a.stream.bufferedBytes!));
  for (final candidate in candidates) {
    final name = devices.byId(candidate.id)?.name;
    final source = name == null
        ? null
        : peerFileForOffer(
            ref.read(syncServiceProvider),
            candidate.id,
            name,
            candidate.stream,
          );
    if (source != null && !excluded.contains(source.url)) return source;
  }
  return null;
}
