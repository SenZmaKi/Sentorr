import 'dart:async';
import 'dart:io';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final _log = Logger('sentorr.net.cache');

/// Keeps a file-backed store under a byte budget by evicting the least
/// recently used responses. Files are named by cache key; use is their write
/// time, or a hit earlier this session, whichever is later.
class SizeLimitedCacheStore extends CacheStore {
  SizeLimitedCacheStore(this._delegate, this.directory, this.maxBytes) {
    unawaited(trim());
  }

  final CacheStore _delegate;
  final Directory directory;

  /// Zero means unlimited; read on every trim so settings apply live.
  final int Function() maxBytes;

  /// Trims down to this share of the budget, so each write does not evict.
  static const _lowWater = 0.9;

  final _usedAt = <String, DateTime>{};
  Future<void>? _trimming;
  bool _trimAgain = false;

  /// Evicts until the store fits its budget, joining a trim already running.
  Future<void> trim() {
    if (_trimming != null) {
      _trimAgain = true;
      return _trimming!;
    }
    return _trimming = () async {
      try {
        do {
          _trimAgain = false;
          await _evict();
        } while (_trimAgain);
      } catch (error, stack) {
        _log.warning('Could not trim the network cache', error, stack);
      } finally {
        _trimming = null;
      }
    }();
  }

  Future<void> _evict() async {
    final limit = maxBytes();
    if (limit <= 0 || !await directory.exists()) return;
    final entries = <(String, int, DateTime)>[];
    var total = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        final key = path.basename(entity.path);
        final hit = _usedAt[key];
        final used = hit != null && hit.isAfter(stat.modified)
            ? hit
            : stat.modified;
        entries.add((key, stat.size, used));
        total += stat.size;
      } on FileSystemException {
        // Replaced or deleted while listing.
      }
    }
    if (total <= limit) return;
    entries.sort((a, b) => a.$3.compareTo(b.$3));
    final target = (limit * _lowWater).floor();
    var evicted = 0;
    for (final (key, size, _) in entries) {
      if (total <= target) break;
      await _delegate.delete(key);
      _usedAt.remove(key);
      total -= size;
      evicted++;
    }
    _log.info('Evicted $evicted cached responses to fit the network cache');
  }

  @override
  Future<CacheResponse?> get(String key) async {
    final response = await _delegate.get(key);
    if (response != null) _usedAt[key] = DateTime.now();
    return response;
  }

  @override
  Future<void> set(CacheResponse response) async {
    await _delegate.set(response);
    unawaited(trim());
  }

  @override
  Future<void> delete(String key, {bool staleOnly = false}) async {
    await _delegate.delete(key, staleOnly: staleOnly);
    if (!staleOnly) _usedAt.remove(key);
  }

  @override
  Future<void> clean({
    CachePriority priorityOrBelow = CachePriority.high,
    bool staleOnly = false,
  }) async {
    await _delegate.clean(
      priorityOrBelow: priorityOrBelow,
      staleOnly: staleOnly,
    );
    if (!staleOnly) _usedAt.clear();
  }

  @override
  Future<bool> exists(String key) => _delegate.exists(key);

  @override
  Future<List<CacheResponse>> getFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) => _delegate.getFromPath(pathPattern, queryParams: queryParams);

  @override
  Future<void> deleteFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) => _delegate.deleteFromPath(pathPattern, queryParams: queryParams);

  @override
  Future<void> close() async {
    await _trimming;
    await _delegate.close();
  }
}
