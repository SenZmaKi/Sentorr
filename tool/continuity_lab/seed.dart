import 'dart:convert';
import 'dart:io';

import 'package:libtorrent_dart/libtorrent_dart.dart';

/// Independent torrent seed in the receiving process. The host can disappear
/// entirely while the receiver's fallback still has a real TCP seed to reach.
Future<Future<void> Function()> startLabSeed(Directory root) async {
  final fixture = File(Platform.environment['SENTORR_LAB_MEDIA']!);
  final metadata = createTorrentData(
    sourcePath: fixture.path,
    pieceSize: 64 * 1024,
  );
  final torrent = await File('${root.path}/seed.torrent')
      .writeAsBytes(metadata);
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
      LibtorrentSettingsTag.enableLsd,
      LibtorrentSettingsTag.enableUpnp,
      LibtorrentSettingsTag.enableNatpmp,
      LibtorrentSettingsTag.enableOutgoingUtp,
      LibtorrentSettingsTag.enableIncomingUtp,
    ])
      LibtorrentTagItem.settingsBool(tag, false),
  ]);
  final source = native.addTorrentData(
    torrentData: metadata,
    savePath: fixture.parent.path,
  );
  source.unsetFlags(
    LibtorrentTorrentFlags.autoManaged | LibtorrentTorrentFlags.paused,
  );
  final clock = Stopwatch()..start();
  while (source.getStatus().state != 5 || native.listenPort == 0) {
    if (clock.elapsed > const Duration(seconds: 15)) {
      native.close();
      throw StateError('Seed timed out');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  http.listen((request) async {
    if (request.uri.path == '/metadata') {
      request.response.add(metadata);
    } else if (request.uri.path == '/announce') {
      request.response.add(utf8.encode('d8:intervali1e5:peers6:'));
      request.response.add([
        127,
        0,
        0,
        1,
        native.listenPort >> 8,
        native.listenPort & 255,
      ]);
      request.response.add([101]);
    } else {
      request.response.statusCode = 404;
    }
    await request.response.close();
  });
  await File('${root.path}/Phone-seed.json').writeAsString(
    jsonEncode({
      'torrent': torrent.path,
      'port': native.listenPort,
      'metadata': 'http://127.0.0.1:${http.port}/metadata',
      'tracker': 'http://127.0.0.1:${http.port}/announce',
    }),
  );
  return () async {
    await http.close(force: true);
    native.close();
  };
}
