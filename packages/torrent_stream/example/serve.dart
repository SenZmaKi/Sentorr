import 'dart:io';

import 'package:torrent_stream/torrent_stream.dart';

/// A player-independent consumer. Serve one explicitly selected torrent file.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run example/serve.dart <magnet-or-torrent-file> <file-index>',
    );
    exitCode = 64;
    return;
  }
  final cache = await Directory.systemTemp.createTemp(
    'torrent-stream-example-',
  );
  final engine = TorrentEngine();
  final session = TorrentStreamSession(
    engine: engine,
    config: TorrentStreamConfig(cacheDirectory: cache.path),
  );
  final telemetry = session.states.listen((state) {
    stderr.writeln(
      '${state.phase.name}/${state.transferState.name} '
      'peers=${state.connectedPeers} seeds=${state.connectedSeeds} '
      'known=${state.knownPeers} '
      'download=${state.downloadBytesPerSecond} B/s '
      'upload=${state.uploadBytesPerSecond} B/s '
      'received=${state.receivedBytes} uploaded=${state.uploadedBytes}',
    );
  });
  try {
    final source = args.first.startsWith('magnet:')
        ? TorrentSource.magnet(Uri.parse(args.first))
        : TorrentSource.file(File(args.first).absolute.path);
    final files = await session.open(source);
    for (final file in files) {
      stdout.writeln('${file.index}: ${file.path} (${file.length} bytes)');
    }
    final stream = await session.prepareFile(int.parse(args[1]));
    stdout.writeln('Ready bytes; player must still parse/cache: ${stream.uri}');
    stdout.writeln('Press Enter to close.');
    await stdin.first;
  } finally {
    await session.close();
    await engine.close();
    await telemetry.cancel();
    await cache.delete(recursive: true);
  }
}
