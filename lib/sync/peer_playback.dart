import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../player/models.dart';
import '../player/stream/offline_source.dart';
import 'devices.dart';
import 'peer_source.dart';
import 'peers.dart';
import 'service.dart';

final _log = Logger('sentorr.sync.playback');

/// Ask every paired device, including those discovery currently marks offline.
/// Slow or sleeping devices must not hold up ordinary torrent playback.
Future<PeerFile?> verifiedPeerSource(
  Ref ref,
  PlaybackItem item,
  Set<Uri> excluded,
) async {
  final peers = ref.read(peersProvider.notifier);
  final devices = ref.read(devicesProvider).paired;
  await Future.wait([
    for (final device in devices)
      peers
          .syncWith(device.id)
          .timeout(const Duration(seconds: 5))
          .catchError(
            (Object error) =>
                _log.fine('Playback refresh ${device.name}: $error'),
          ),
  ]);
  if (!ref.mounted) return null;
  final service = ref.read(syncServiceProvider);
  final candidates = <PeerFile>[];
  final tried = {...excluded};
  while (true) {
    final candidate = sharedPeerSource(
      ref,
      ref.read(peersProvider),
      item,
      excluded: tried,
    );
    if (candidate is! PeerFile) break;
    tried.add(candidate.url);
    candidates.add(candidate);
  }
  // Probe in parallel but retain finished-file / buffered-byte preference.
  final available = await Future.wait([
    for (final candidate in candidates)
      _probe(
        service,
        candidate,
      ).timeout(const Duration(seconds: 3), onTimeout: () => false),
  ]);
  if (!ref.mounted) return null;
  for (var i = 0; i < candidates.length; i++) {
    if (available[i]) return candidates[i];
  }
  return null;
}

Future<bool> _probe(SyncService service, PeerFile candidate) async {
  final id = candidate.url.pathSegments[1];
  final route = service.proxy.route(id);
  if (route == null) return false;
  try {
    final response = await service.client.open(
      route.address,
      route.fingerprint,
      '/v1/${candidate.buffered ? 'buffered' : 'media'}/${candidate.url.pathSegments[2]}',
      method: 'HEAD',
      headers: {
        if (candidate.url.queryParameters['version'] case final version?)
          HttpHeaders.ifMatchHeader: '"$version"',
        if (candidate.buffered)
          'x-sentorr-torrent': candidate.url.queryParameters['hash'] ?? '',
      },
    );
    final available = response.statusCode == 200 || response.statusCode == 206;
    await response.drain<void>();
    return available;
  } catch (error) {
    _log.fine('Peer offer ${candidate.deviceName} unavailable: $error');
    return false;
  }
}
