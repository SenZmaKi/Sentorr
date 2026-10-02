import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import '../../shared/persistence/directory_size.dart';
import '../../shared/persistence/json_file_store.dart';

final _log = Logger('sentorr.player.cache');

/// Keeps the files of recently watched torrents, so watching one again
/// starts from what was already downloaded. Each lives in a folder named
/// after its info hash under the torrent folder in use when it was watched;
/// the least recently watched go first. Only folders it recorded, and
/// sessions' leftover temporary folders, are ever deleted.
class TorrentCache {
  TorrentCache(this.index);

  /// Prefix the streaming engine gives sessions that keep nothing.
  static const temporaryPrefix = 'torrent-stream-';

  final JsonFileStore index;
  Future<void> _tail = Future.value();

  /// Marks [infoHash] watched under [root] and removes kept torrents past
  /// the newest [keep]. Returns the folder name the session should keep,
  /// or null when [keep] is zero and nothing is kept.
  Future<String?> use(String root, String infoHash, {required int keep}) =>
      _serial(() async {
        final entries = await _read();
        final hash = infoHash.toLowerCase();
        entries.removeWhere((e) => e.hash == hash && e.root == root);
        if (keep > 0) entries.insert(0, _Entry(hash, root, DateTime.now()));
        final evicted = entries.skip(keep).toList();
        entries.removeRange(keep.clamp(0, entries.length), entries.length);
        for (final e in evicted) {
          await _delete(e.directory);
        }
        await _write(entries);
        return keep > 0 ? hash : null;
      });

  /// Bytes on disk for kept torrents and leftovers under [roots].
  Future<int> size(Iterable<String> roots) => _serial(() async {
    var total = 0;
    for (final d in await _folders(roots)) {
      total += await directorySize(d);
    }
    return total;
  });

  /// Deletes every kept torrent and leftover under [roots].
  Future<void> clear(Iterable<String> roots) => _serial(() async {
    for (final d in await _folders(roots)) {
      await _delete(d);
    }
    await _write(const []);
  });

  Future<List<Directory>> _folders(Iterable<String> roots) async {
    final kept = [for (final e in await _read()) e.directory];
    final leftovers = <Directory>[];
    for (final root in {...roots, for (final d in kept) d.parent.path}) {
      final dir = Directory(root);
      if (!await dir.exists()) continue;
      await for (final child in dir.list(followLinks: false)) {
        if (child is Directory &&
            path.basename(child.path).startsWith(temporaryPrefix)) {
          leftovers.add(child);
        }
      }
    }
    return [...kept, ...leftovers];
  }

  Future<List<_Entry>> _read() async {
    final json = await index.read();
    final entries = json?['entries'];
    if (entries is! List) return [];
    return [...entries.map(_Entry.fromJson).nonNulls];
  }

  Future<void> _write(List<_Entry> entries) => index.write({
    'entries': [for (final e in entries) e.toJson()],
  });

  Future<void> _delete(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException catch (error) {
      _log.warning('Could not remove ${dir.path}', error);
    }
  }

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}

class _Entry {
  const _Entry(this.hash, this.root, this.usedAt);
  final String hash, root;
  final DateTime usedAt;

  Directory get directory => Directory(path.join(root, hash));

  static _Entry? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final hash = json['hash'], root = json['root'];
    final at = DateTime.tryParse(json['usedAt'] as String? ?? '');
    if (hash is! String || root is! String || at == null) return null;
    // Only plain hash names, so a bad index can never point at other files.
    if (!RegExp(r'^([0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(hash)) return null;
    return _Entry(hash, root, at);
  }

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'root': root,
    'usedAt': usedAt.toUtc().toIso8601String(),
  };
}
