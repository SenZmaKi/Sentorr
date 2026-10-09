import 'dart:async';

import 'package:libtorrent_dart/libtorrent_dart.dart';

import '../config.dart';
import '../models.dart';
import 'media_indexing.dart';
import '../media/media_index.dart';
import 'downloaded_ranges.dart';
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
  final availability = DownloadedRanges();
  late final indexing = MediaIndexing(
    file.size,
    bytes.readIndex,
    bytes.release,
  );
  MediaIndex? get mediaIndex => indexing.index;
  List<DownloadedRange>? _projected;
  MediaIndex? _projectedIndex;
  List<MediaTimeRange> _times = const [];
  List<MediaTimeRange> get downloadedTimes {
    if (!identical(_projected, availability.ranges) ||
        !identical(_projectedIndex, mediaIndex)) {
      _projected = availability.ranges;
      _projectedIndex = mediaIndex;
      _times = mediaIndex?.available(availability.ranges) ?? const [];
    }
    return _times;
  }

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
    indexing.refresh(0);
    return server.uri.toString();
  }

  Future<void> close() async {
    lifetime.cancel();
    indexing.close();
    await server?.close();
    bytes.close();
  }
}
