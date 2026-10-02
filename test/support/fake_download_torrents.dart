import 'dart:async';

import 'package:sentorr/downloads/torrents.dart';
import 'package:torrent_stream/torrent_stream.dart';

class FakeTorrent {
  final owners = <String>{};
  final paused = <String>{};
  final wanted = <int>{};
  final renames = <int, String>{};
  int done = 0, uploaded = 0;
  bool streaming = false, deleted = false;
  String? error;
}

/// Torrents keyed by the magnet's display name.
class FakeTorrents implements DownloadTorrents {
  final byHash = <String, FakeTorrent>{};
  bool failMetadata = false;
  Completer<void>? metadataGate;

  FakeTorrent operator [](String title) => byHash[title]!;
  bool running(String title) {
    final t = byHash[title];
    return t != null &&
        t.owners.isNotEmpty &&
        !t.owners.every(t.paused.contains);
  }

  @override
  List<TorrentSnapshot> get torrents => [
    for (final MapEntry(key: hash, value: t) in byHash.entries)
      if (t.owners.isNotEmpty)
        TorrentSnapshot(
          infoHash: hash,
          savePath: '/downloads',
          storage: TorrentStorage.kept,
          owners: t.owners,
          fileBytes: [0, t.done],
          uploadedBytes: t.uploaded,
          error: t.error,
          streams: [
            if (t.streaming)
              const StreamSnapshot(
                id: 1,
                owner: 'stream:1',
                file: TorrentStreamFile(
                  index: 1,
                  path: 'selected.mkv',
                  length: 100,
                  isPadFile: false,
                ),
              ),
          ],
        ),
  ];

  @override
  Future<String> add(
    TorrentSource source, {
    required String owner,
    required String directory,
  }) async {
    final hash = (source as MagnetSource).uri.queryParameters['dn']!;
    byHash.putIfAbsent(hash, FakeTorrent.new).owners.add(owner);
    return hash;
  }

  @override
  Future<List<TorrentStreamFile>> metadata(String infoHash) async {
    await metadataGate?.future;
    if (failMetadata) throw StateError('no metadata');
    return const [
      TorrentStreamFile(index: 0, path: 'a.nfo', length: 10, isPadFile: false),
      TorrentStreamFile(
        index: 1,
        path: 'selected.mkv',
        length: 100,
        isPadFile: false,
      ),
    ];
  }

  @override
  Future<void> rename(String infoHash, Map<int, String> names) async =>
      byHash[infoHash]!.renames.addAll(names);

  @override
  Future<void> want(String infoHash, String owner, Set<int> files) async =>
      byHash[infoHash]!.wanted.addAll(files);

  @override
  Future<void> setPaused(String infoHash, String owner, bool paused) async {
    final t = byHash[infoHash]!;
    paused ? t.paused.add(owner) : t.paused.remove(owner);
  }

  @override
  Future<void> release(
    String infoHash,
    String owner, {
    bool deleteFiles = false,
  }) async {
    final t = byHash[infoHash]!;
    t.owners.remove(owner);
    t.paused.remove(owner);
    t.deleted = deleteFiles;
  }
}
