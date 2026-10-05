import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_stream/torrent_stream.dart';

import 'trackers.dart';
import '../settings/models.dart';
import '../settings/notifier.dart';

/// Session-wide limits from settings, shared by streams and downloads.
TorrentEngineSettings engineSettingsOf(AppSettings settings) {
  final n = settings.network;
  return TorrentEngineSettings(
    downloadBytesPerSecond: n.downloadLimitBytesPerSecond,
    uploadBytesPerSecond: n.uploadLimitBytesPerSecond,
    maxConnections: n.maxConnections,
    defaultTrackers: defaultTorrentTrackers,
    transport: n.utp ? TorrentTransport.mixedTcpUtp : TorrentTransport.tcpOnly,
    enableDht: n.dht,
    enableLsd: n.lsd,
    enableUpnp: n.upnp,
    enableNatPmp: n.natPmp,
    proxy: n.proxy.engine,
    networkInterface: n.networkInterface,
  );
}

/// The app's one torrent session: every stream and download goes through
/// it, so watching a download shares its torrent. Bootstrap closes it.
final torrentEngineProvider = Provider<TorrentEngine>((ref) {
  final engine = TorrentEngine(
    settings: engineSettingsOf(ref.read(settingsProvider)),
  );
  ref.listen(
    settingsProvider.select((s) => s.network),
    (_, _) => unawaited(
      engine.configure(engineSettingsOf(ref.read(settingsProvider))),
    ),
  );
  ref.onDispose(() => unawaited(engine.close()));
  return engine;
});
