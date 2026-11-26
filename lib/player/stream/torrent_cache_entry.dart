part of 'torrent_cache.dart';

/// A kept torrent in the index: where it is and when it was last watched.
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
