import 'dart:io';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:torrent_stream/torrent_stream.dart';

/// An engine reaching only explicit loopback peers.
TorrentEngine loopbackEngine({int downloadBytesPerSecond = 0}) => TorrentEngine(
  settings: TorrentEngineSettings(
    downloadBytesPerSecond: downloadBytesPerSecond,
    transport: TorrentTransport.tcpOnly,
    enableDht: false,
    enableLsd: false,
    enableUpnp: false,
    enableNatPmp: false,
    listenInterfaces: '127.0.0.1:0',
  ),
);

/// A loopback libtorrent session seeding [file]'s torrent; returns the
/// torrent metadata, the peer to reach it and a close.
Future<(Uint8List, TorrentPeer, void Function())> seedFile(
  File file, {
  int pieceSize = 128 * 1024,
}) async {
  final metadata = createTorrentData(
    sourcePath: file.path,
    pieceSize: pieceSize,
  );
  final native = createSessionFromTags([
    LibtorrentTagItem.settingsBool(
      LibtorrentSettingsTag.closeRedundantConnections,
      false,
    ),
    LibtorrentTagItem.settingsString(
      LibtorrentSettingsTag.listenInterfaces,
      '127.0.0.1:0',
    ),
    for (final tag in [
      LibtorrentSettingsTag.enableDht,
      LibtorrentSettingsTag.enableUpnp,
      LibtorrentSettingsTag.enableNatpmp,
      LibtorrentSettingsTag.enableLsd,
      LibtorrentSettingsTag.enableOutgoingUtp,
      LibtorrentSettingsTag.enableIncomingUtp,
    ])
      LibtorrentTagItem.settingsBool(tag, false),
  ]);
  final seed = native.addTorrentData(
    torrentData: metadata,
    savePath: file.parent.path,
  );
  seed.unsetFlags(
    LibtorrentTorrentFlags.autoManaged | LibtorrentTorrentFlags.paused,
  );
  final watch = Stopwatch()..start();
  while (seed.getStatus().state != 5 || native.listenPort == 0) {
    if (watch.elapsed > const Duration(seconds: 10)) {
      throw StateError('Seed not ready');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return (metadata, TorrentPeer('127.0.0.1', native.listenPort), native.close);
}

/// The next engine update satisfying [test].
Future<TorrentSnapshot> until(
  TorrentEngine engine,
  String hash,
  bool Function(TorrentSnapshot) test, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final now = engine.torrent(hash);
  if (now != null && test(now)) return now;
  final update = await engine.states
      .map((all) => all.where((t) => t.infoHash == hash).firstOrNull)
      .firstWhere((t) => t != null && test(t))
      .timeout(timeout);
  return update!;
}
