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
  final session = TorrentStreamSession(
    config: TorrentStreamConfig(cacheDirectory: cache.path),
  );
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
    await cache.delete(recursive: true);
  }
}
