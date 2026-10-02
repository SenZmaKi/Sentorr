import 'dart:convert';
import 'dart:io';

import 'package:libtorrent_dart/libtorrent_dart.dart';

Future<void> main(List<String> args) async {
  final file = File(args[0]);
  final metadata = createTorrentData(
    sourcePath: file.path,
    pieceSize: 128 * 1024,
  );
  final native = createSessionFromTags([
    LibtorrentTagItem.settingsString(
      LibtorrentSettingsTag.listenInterfaces,
      '127.0.0.1:0',
    ),
    LibtorrentTagItem.settingsBool(
      LibtorrentSettingsTag.closeRedundantConnections,
      false,
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
  seed.setUploadLimit(1024 * 1024);
  seed.unsetFlags(
    LibtorrentTorrentFlags.autoManaged | LibtorrentTorrentFlags.paused,
  );
  final clock = Stopwatch()..start();
  while (seed.getStatus().state != 5 || native.listenPort == 0) {
    if (clock.elapsed.inSeconds > 30) throw StateError('Seed not ready');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  await File(args[1]).writeAsString(
    jsonEncode({'torrent': base64Encode(metadata), 'port': native.listenPort}),
  );
  ProcessSignal.sigterm.watch().listen((_) {
    native.close();
    exit(0);
  });
  await Future<void>.delayed(const Duration(hours: 1));
  native.close();
}
