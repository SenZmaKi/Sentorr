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
import 'client.dart';
import 'copy_offer.dart';
import 'peer_file.dart';
import '../shared/parallel.dart';

final _log = Logger('sentorr.sync.playback');

final peerLibraryRefreshProvider = Provider<PeerLibraryRefresh>(
  PeerLibraryRefresh.new,
);

/// Coalesce simultaneous playback/download discovery. Recent successful
/// refresh attempts can be reused for two seconds instead of resyncing for
/// each item in a season or each open player.
class PeerLibraryRefresh {
  PeerLibraryRefresh(this.ref);
  final Ref ref;
  Future<void>? _running;
  DateTime? _last;

  Future<void> refresh() {
    if (_running case final running?) return running;
    if (_last != null &&
        DateTime.now().difference(_last!) < const Duration(seconds: 2)) {
      return Future.value();
    }
    return _running = _refresh().whenComplete(() {
      _running = null;
      _last = DateTime.now();
    });
  }

  Future<void> _refresh() async {
    final peers = ref.read(peersProvider.notifier);
    final clock = Stopwatch()..start();
    await parallelMapOrdered(
      ref.read(devicesProvider).paired,
      maxConcurrent: 4,
      operation: (device) async {
        final remaining = const Duration(seconds: 5) - clock.elapsed;
        if (remaining <= Duration.zero || !ref.mounted) return;
        try {
          await peers.syncWith(device.id).timeout(remaining);
        } catch (error) {
          _log.fine('Source refresh ${device.name}: $error');
        }
      },
    );
  }
}

Future<CopyOffer?> verifiedPeerCopy(Ref ref, PlaybackItem item) async {
  await ref.read(peerLibraryRefreshProvider).refresh();
  if (!ref.mounted) return null;
  final service = ref.read(syncServiceProvider);
  final peers = ref.read(peersProvider);
  final candidates =
      [
        for (final device in ref.read(devicesProvider).paired)
          if (peers[device.id] case final peer? when peer.online)
            for (final media in [
              ...peer.media,
              ...peer.streams.where((m) => m.version == m.bufferedVersion),
            ])
              if (media.id == item.id)
                (deviceId: device.id, deviceName: device.name, media: media),
      ]..sort((a, b) {
        final kind = (a.media.bufferedBytes == null ? 0 : 1).compareTo(
          b.media.bufferedBytes == null ? 0 : 1,
        );
        return kind != 0
            ? kind
            : (b.media.bufferedBytes ?? 0).compareTo(
                a.media.bufferedBytes ?? 0,
              );
      });
  final available = await Future.wait([
    for (final copy in candidates)
      () async {
        final source = peerFileForOffer(
          service,
          copy.deviceId,
          copy.deviceName,
          copy.media,
        );
        return source != null && await _probe(service, source);
      }(),
  ]);
  if (!ref.mounted) return null;
  for (var i = 0; i < candidates.length; i++) {
    if (available[i]) return CopyOffer([candidates[i]]);
  }
  return null;
}

/// Verify nearby devices while torrent discovery runs independently.
Future<PeerFile?> verifiedPeerSource(
  Ref ref,
  PlaybackItem item,
  Set<Uri> excluded,
) async {
  await ref.read(peerLibraryRefreshProvider).refresh();
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
  final request = PeerRequest();
  try {
    final response = await request
        .wait(
          service.client.open(
            route.address,
            route.fingerprint,
            '/v1/${candidate.buffered ? 'buffered' : 'media'}/${candidate.url.pathSegments[2]}',
            method: 'HEAD',
            cancellation: request,
            headers: {
              if (candidate.url.queryParameters['version'] case final version?)
                HttpHeaders.ifMatchHeader: '"$version"',
              if (candidate.buffered)
                'x-sentorr-torrent':
                    candidate.url.queryParameters['hash'] ?? '',
            },
          ),
        )
        .timeout(const Duration(seconds: 3));
    final available = response.statusCode == 200 || response.statusCode == 206;
    await response.drain<void>();
    return available;
  } catch (error) {
    _log.fine('Peer offer ${candidate.deviceName} unavailable: $error');
    return false;
  } finally {
    request.cancel();
  }
}
