import 'package:torrent_stream/torrent_stream.dart';

/// The torrent engine as the download queue uses it: kept torrents, held
/// under each download's owner name.
abstract interface class DownloadTorrents {
  List<TorrentSnapshot> get torrents;
  Future<String> add(
    TorrentSource source, {
    required String owner,
    required String directory,
  });
  Future<List<TorrentStreamFile>> metadata(String infoHash);
  Future<void> rename(String infoHash, Map<int, String> names);
  Future<void> want(String infoHash, String owner, Set<int> files);
  Future<void> setPaused(String infoHash, String owner, bool paused);
  Future<void> release(String infoHash, String owner, {bool deleteFiles});
}

class EngineTorrents implements DownloadTorrents {
  EngineTorrents(this.engine);
  final TorrentEngine engine;

  @override
  List<TorrentSnapshot> get torrents => engine.torrents;

  @override
  Future<String> add(
    TorrentSource source, {
    required String owner,
    required String directory,
  }) => engine.add(
    source,
    owner: owner,
    directory: directory,
    storage: TorrentStorage.kept,
  );

  @override
  Future<List<TorrentStreamFile>> metadata(String infoHash) =>
      engine.metadata(infoHash);

  @override
  Future<void> rename(String infoHash, Map<int, String> names) =>
      engine.rename(infoHash, names);

  @override
  Future<void> want(String infoHash, String owner, Set<int> files) =>
      engine.want(infoHash, owner, files);

  @override
  Future<void> setPaused(String infoHash, String owner, bool paused) =>
      engine.setPaused(infoHash, owner, paused);

  @override
  Future<void> release(
    String infoHash,
    String owner, {
    bool deleteFiles = false,
  }) => engine.release(infoHash, owner, deleteFiles: deleteFiles);
}
