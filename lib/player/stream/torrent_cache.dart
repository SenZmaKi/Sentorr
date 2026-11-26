import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import '../../shared/persistence/directory_size.dart';
import '../../shared/persistence/json_file_store.dart';

import '../../torrents/models.dart';
import 'reusable_torrent.dart';

part 'torrent_cache_entry.dart';

final _log = Logger('sentorr.player.cache');

/// Keeps the files of recently watched torrents within a byte budget, so
/// watching one again starts from what was already downloaded. Each lives
/// in a folder named after its info hash under the torrent folder in use
/// when it was watched; the least recently watched go first. Only folders
/// it recorded, and sessions' leftover temporary folders, are ever deleted.
class TorrentCache {
  TorrentCache(this.index, {required this.budget});

  /// Prefix the streaming engine gives sessions that keep nothing.
  static const temporaryPrefix = 'torrent-stream-';

  final JsonFileStore index;

  /// Bytes kept torrents may take; zero keeps none.
  final int Function() budget;
  final _changes = StreamController<int>.broadcast();
  var _revision = 0;
  Stream<int> get changes => _changes.stream;
  Future<void> close() => _serial(() => _changes.close());
  Future<void> _tail = Future.value();

  /// Marks [infoHash] watched under [root] and removes kept torrents the
  /// budget no longer fits. Returns the folder name the session should
  /// keep, or null when the budget is zero and nothing is kept.
  Future<String?> use(String root, String infoHash) => _serial(() async {
    final entries = await _read();
    final hash = infoHash.toLowerCase();
    final keep = budget() > 0;
    final previous = entries
        .where((e) => e.hash == hash && e.root == root)
        .firstOrNull;
    entries.remove(previous);
    if (keep) {
      _pendingDelete.remove(_key(Directory(path.join(root, hash))));
      entries.insert(
        0,
        _Entry(hash, root, DateTime.now(), previous?.items ?? const {}),
      );
    } else if (previous != null) {
      await _delete(previous.directory);
    }
    await _trim(entries, playing: keep ? hash : null);
    await _write(entries);
    return keep ? hash : null;
  });

  /// Removes kept torrents the budget no longer fits, e.g. after it was
  /// lowered.
  Future<void> trim() => _serial(() async {
    final entries = await _read();
    if (await _trim(entries)) await _write(entries);
  });

  /// Evicts from [entries], least recently watched first, until what is
  /// kept fits the budget, and any torrent too big to keep on its own.
  /// [playing] counts as [reserve] bytes at least, the size of its file,
  /// so the budget holds while it downloads. It and pinned folders stay
  /// for now; one too big for the budget goes once released. Returns
  /// whether any went.
  Future<bool> _trim(
    List<_Entry> entries, {
    String? playing,
    int reserve = 0,
  }) async {
    final limit = budget();
    bool held(_Entry e) =>
        e.hash == playing || _pins.containsKey(_key(e.directory));
    final sizes = <_Entry, int>{};
    for (final e in entries) {
      final size = await directorySize(e.directory);
      sizes[e] = e.hash == playing && reserve > size ? reserve : size;
    }
    // Too big to keep on their own: they go whatever else is kept.
    bool oversized(_Entry e) => sizes[e]! > limit;
    var total = 0;
    for (final e in entries) {
      if (!oversized(e)) total += sizes[e]!;
    }
    final evicted = <_Entry>[];
    for (final e in entries.reversed) {
      if (held(e)) continue;
      if (oversized(e)) {
        evicted.add(e);
      } else if (total > limit) {
        evicted.add(e);
        total -= sizes[e]!;
      }
    }
    for (final e in evicted) {
      _log.info('Evicting kept torrent ${e.hash} from ${e.root}');
      entries.remove(e);
      await _delete(e.directory);
    }
    return evicted.isNotEmpty;
  }

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
    // The file playing is known now: make room for all of it.
    await _trim(entries, playing: entry.hash, reserve: torrent.size);
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
        final key = _key(Directory(cached.directory));
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
          // Released, a torrent too big for the budget can go.
          final entries = await _read();
          if (await _trim(entries)) await _write(entries);
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

  static String _key(Directory dir) => path.normalize(path.absolute(dir.path));

  Future<void> _delete(Directory dir) async {
    final key = _key(dir);
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
