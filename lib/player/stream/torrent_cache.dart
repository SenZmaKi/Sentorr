import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import '../../shared/persistence/directory_size.dart';
import '../../shared/persistence/json_file_store.dart';

import '../../torrents/models.dart';
import 'reusable_torrent.dart';

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
  final _changes = StreamController<int>.broadcast();
  var _revision = 0;
  Stream<int> get changes => _changes.stream;
  Future<void> close() => _serial(() => _changes.close());
  Future<void> _tail = Future.value();

  /// Marks [infoHash] watched under [root] and removes kept torrents past
  /// the newest [keep]. Returns the folder name the session should keep,
  /// or null when [keep] is zero and nothing is kept.
  Future<String?> use(String root, String infoHash, {required int keep}) =>
      _serial(() async {
        final entries = await _read();
        final hash = infoHash.toLowerCase();
        final previous = entries
            .where((e) => e.hash == hash && e.root == root)
            .firstOrNull;
        entries.remove(previous);
        if (keep > 0) {
          _pendingDelete.remove(
            path.normalize(path.absolute(path.join(root, hash))),
          );
          entries.insert(
            0,
            _Entry(hash, root, DateTime.now(), previous?.items ?? const {}),
          );
        }
        final evicted = entries.skip(keep).toList();
        entries.removeRange(keep.clamp(0, entries.length), entries.length);
        for (final e in evicted) {
          _log.info('Evicting kept torrent ${e.hash} from ${e.root}');
          await _delete(e.directory);
        }
        await _write(entries);
        return keep > 0 ? hash : null;
      });

  Future<void> remember(
    String itemId,
    String directory,
    ReusableTorrent torrent,
    Uint8List metadata,
  ) => _serial(() async {
    final entries = await _read();
    final entry = entries
        .where(
          (e) =>
              path.equals(e.directory.path, directory) &&
              e.hash == torrent.release.infoHash.toLowerCase(),
        )
        .firstOrNull;
    if (entry == null || !await entry.directory.exists()) return;
    await cachedTorrentMetadata(directory).writeAsBytes(metadata);
    entries[entries.indexOf(entry)] = _Entry(
      entry.hash,
      entry.root,
      entry.usedAt,
      {...entry.items, itemId: torrent},
    );
    await _write(entries);
  });

  Future<CachedTorrent?> find(String itemId, {TorrentRelease? previous}) =>
      _serial(() async {
        for (final entry in await _read()) {
          final torrent =
              entry.items[itemId] ??
              (entry.hash == previous?.infoHash.toLowerCase()
                  ? ReusableTorrent(previous!, null, null, previous.sizeBytes)
                  : null);
          if (torrent != null && await _hasPayload(entry, torrent)) {
            return (torrent: torrent, directory: entry.directory.path);
          }
        }
        return null;
      });

  Future<List<CachedTorrent>> saved() => _serial(
    () async => [
      for (final entry in await _read())
        for (final torrent in entry.items.values)
          if (await _hasPayload(entry, torrent))
            (torrent: torrent, directory: entry.directory.path),
    ],
  );

  Future<String?> directoryFor(String hash) => _serial(() async {
    for (final entry in await _read()) {
      if (entry.hash == hash.toLowerCase() && await entry.directory.exists()) {
        return entry.directory.path;
      }
    }
    return null;
  });

  final _pins = <String, int>{};
  final _pendingDelete = <String>{};

  /// Pin a cache folder while a verified-byte server is using it. Eviction
  /// removes its offer immediately and defers disk deletion until release.
  Future<Future<void> Function()?> acquire(CachedTorrent cached) =>
      _serial(() async {
        final valid = (await _read()).any(
          (entry) => path.equals(entry.directory.path, cached.directory),
        );
        if (!valid || !await Directory(cached.directory).exists()) return null;
        final key = path.normalize(path.absolute(cached.directory));
        _pins[key] = (_pins[key] ?? 0) + 1;
        var released = false;
        return () => _serial(() async {
          if (released) return;
          released = true;
          final count = _pins[key]! - 1;
          if (count > 0) {
            _pins[key] = count;
            return;
          }
          _pins.remove(key);
          if (_pendingDelete.remove(key)) await _delete(Directory(key));
        });
      });

  /// Serialize reuse with eviction and manual cache clearing. Recheck after
  /// confirmation, since the cache can change while the prompt is open.
  Future<bool> reuse(
    CachedTorrent cached,
    Future<void> Function() save, {
    bool requirePayload = true,
  }) => _serial(() async {
    final entries = await _read();
    final entry = entries
        .where(
          (e) =>
              path.equals(e.directory.path, cached.directory) &&
              e.hash == cached.torrent.release.infoHash.toLowerCase(),
        )
        .firstOrNull;
    if (entry == null ||
        (requirePayload && !await _hasPayload(entry, cached.torrent))) {
      return false;
    }
    await save();
    return true;
  });

  Future<bool> _hasPayload(_Entry entry, ReusableTorrent torrent) async {
    final dir = entry.directory.path;
    if (torrent.filePath case final filePath?) {
      if (!await cachedTorrentMetadata(dir).exists()) return false;
      final file = path.normalize(path.join(dir, filePath));
      if (path.isWithin(dir, file) && await File(file).exists()) return true;
    }
    if (!await entry.directory.exists()) return false;
    // A hybrid torrent's partfile can use its v2 hash.
    return entry.directory
        .list(recursive: torrent.filePath == null, followLinks: false)
        .any(
          (child) =>
              child is File &&
              (path.extension(child.path) == '.parts' ||
                  (torrent.filePath == null &&
                      !path.basename(child.path).startsWith('.'))),
        );
  }

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
    final folders = await _folders(roots);
    _log.info('Clearing ${folders.length} kept torrent folders');
    for (final d in folders) {
      await _delete(d);
    }
    await _write(const []);
  });

  Future<List<Directory>> _folders(Iterable<String> roots) async {
    final kept = {
      for (final e in await _read())
        path.normalize(path.absolute(e.directory.path)),
      ..._pins.keys,
    }.map(Directory.new).toList();
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

  Future<void> _write(List<_Entry> entries) async {
    await index.write({
      'entries': [for (final e in entries) e.toJson()],
    });
    if (!_changes.isClosed) _changes.add(++_revision);
  }

  Future<void> _delete(Directory dir) async {
    final key = path.normalize(path.absolute(dir.path));
    if (_pins.containsKey(key)) {
      _pendingDelete.add(key);
      return;
    }
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
  const _Entry(this.hash, this.root, this.usedAt, this.items);
  final String hash, root;
  final DateTime usedAt;
  final Map<String, ReusableTorrent> items;

  Directory get directory => Directory(path.join(root, hash));

  static _Entry? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final hash = json['hash'], root = json['root'];
    final at = DateTime.tryParse(json['usedAt'] as String? ?? '');
    if (hash is! String || root is! String || at == null) return null;
    // Only plain hash names, so a bad index can never point at other files.
    if (!RegExp(r'^([0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(hash)) return null;
    final items = json['items'];
    return _Entry(hash, root, at, {
      if (items is Map<String, dynamic>)
        for (final entry in items.entries)
          if (ReusableTorrent.fromJson(entry.value, itemId: entry.key)
              case final torrent?)
            if (torrent.release.infoHash.toLowerCase() == hash)
              entry.key: torrent,
    });
  }

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'root': root,
    'usedAt': usedAt.toUtc().toIso8601String(),
    if (items.isNotEmpty)
      'items': items.map((id, torrent) => MapEntry(id, torrent.toJson())),
  };
}
