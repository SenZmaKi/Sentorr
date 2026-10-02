import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../settings/models.dart';
import '../settings/notifier.dart';

/// Session-wide limits from settings, shared by streams and downloads.
TorrentEngineSettings engineSettingsOf(AppSettings settings) {
  final s = settings.streaming;
  return TorrentEngineSettings(
    downloadBytesPerSecond: s.downloadLimitBytesPerSecond,
    transport: s.utp ? TorrentTransport.mixedTcpUtp : TorrentTransport.tcpOnly,
  );
}

/// The app's one torrent session: every stream and download goes through
/// it, so watching a download shares its torrent. Bootstrap closes it.
final torrentEngineProvider = Provider<TorrentEngine>((ref) {
  final engine = TorrentEngine(
    settings: engineSettingsOf(ref.read(settingsProvider)),
  );
  ref.listen(
    settingsProvider.select(engineSettingsOf),
    (_, next) => unawaited(engine.configure(next)),
  );
  ref.onDispose(() => unawaited(engine.close()));
  return engine;
});
