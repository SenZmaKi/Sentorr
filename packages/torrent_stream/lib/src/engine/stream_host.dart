import 'dart:async';

import 'package:libtorrent_dart/libtorrent_dart.dart';

import '../config.dart';
import 'cancellation.dart';
import 'media_bootstrap.dart';
import 'media_server.dart';
import 'native_session.dart';
import 'torrent_bytes.dart';
import 'torrent_entry.dart';

/// One file of a torrent served over loopback HTTP for one owner, reading
/// through the torrent's shared scheduler.
class StreamHost {
  StreamHost(this.id, this.owner, this.file, this.bytes);

  /// [file] of [entry], read with [options]' window and timeouts.
  factory StreamHost.open(
    int id,
    String owner,
    TorrentEntry entry,
    TorrentFileEntry file,
    NativeSession native,
    StreamOptions options,
  ) => StreamHost(
    id,
    owner,
    file,
    TorrentBytes(
      entry.handle,
      file,
      (piece, cancel) => native.read(
        entry.handle,
        piece,
        cancel,
        pieceTimeout: options.pieceTimeout,
        readTimeout: options.nativeReadTimeout,
      ),
      entry.scheduler!,
      readAheadBytes: options.readAheadBytes,
      maxCacheBytes: options.pieceCacheBytes,
    ),
  );

  final int id;
  final String owner;
  final TorrentFileEntry file;
  final TorrentBytes bytes;
  final lifetime = Cancellation();
  MediaServer? server;

  /// Serves immediately and optionally warms the header in the background.
  /// Read errors surface through HTTP; warming cannot prevent serving.
  Future<String> start(bool prepare) async {
    lifetime.check();
    final server = this.server = MediaServer(bytes);
    await server.start();
    lifetime.check();
    if (prepare) {
      unawaited(
        bootstrapMedia(bytes, lifetime, (_) {}).catchError((Object _) {}),
      );
    }
    return server.uri.toString();
  }

  Future<void> close() async {
    lifetime.cancel();
    await server?.close();
    bytes.close();
  }
}
