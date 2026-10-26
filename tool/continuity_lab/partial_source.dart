import 'dart:convert';
import 'dart:io';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:torrent_stream/torrent_stream.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/stream/parked_stream.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';

Future<({ParkedStream stream, void Function() closeSeed})> partialSource(
  TorrentEngine engine,
  File fixture,
  PlaybackItem item,
  Directory root,
) async {
  final rendezvous = File('${root.parent.path}/Phone-seed.json');
  final clock = Stopwatch()..start();
  while (!rendezvous.existsSync()) {
    if (clock.elapsed > const Duration(seconds: 30)) {
      throw StateError('Seed not ready');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  final seed = jsonDecode(await rendezvous.readAsString()) as Map;
  final metadata = await File(seed['torrent'] as String).readAsBytes();
  final hash = loadTorrentFile(seed['torrent'] as String).infohashHex;
  await engine.configure(
    TorrentEngineSettings(
      transport: TorrentTransport.tcpOnly,
      enableDht: false,
      enableLsd: false,
      enableUpnp: false,
      enableNatPmp: false,
      listenInterfaces: '127.0.0.1:0',
    ),
  );
  final session = TorrentStreamSession(
    engine: engine,
    config: TorrentStreamConfig(
      cacheDirectory: '${root.path}/partial-cache',
      readAheadBytes: 64 * 1024,
      pieceCacheBytes: 0,
      downloadAheadMinutes: 1,
    ),
  );
  final files = await session.open(
    TorrentSource.metadata(metadata),
    peers: [TorrentPeer('127.0.0.1', seed['port'] as int)],
  );
  final stream = await session.prepareFile(files.single.index);
  final magnet = Uri(
    scheme: 'magnet',
    queryParameters: {'xt': 'urn:btih:$hash', 'tr': seed['tracker'] as String},
  );
  final candidate = TorrentCandidate(
    release: TorrentRelease(
      source: TorrentSourceId.pirateBay,
      name: 'Lab partial fixture',
      infoHash: hash,
      magnet: magnet,
      torrentUrls: [Uri.parse(seed['metadata'] as String)],
      seeders: 1,
      sizeBytes: await fixture.length(),
    ),
    score: 1,
    qualityScore: 1,
    availabilityScore: 1,
    sizeScore: 1,
    requiresFileSelection: false,
  );
  return (
    stream: ParkedStream(
      itemId: item.id,
      candidate: candidate,
      session: session,
      stream: stream,
    ),
    closeSeed: () {},
  );
}
