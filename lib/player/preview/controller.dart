import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'extractor.dart';

/// Serial, latest-request-wins extraction with a byte-bounded session cache.
class PreviewController extends ValueNotifier<Uint8List?> {
  PreviewController({
    required this.source,
    required this.allowed,
    PreviewExtractor? extractor,
    this.onDiagnostic,
    this.available,
    this.bucket = const Duration(seconds: 5),
  }) : _extractor = extractor ?? PreviewExtractor(),
       super(null);
  final String? Function() source;
  final bool Function() allowed;
  final FutureOr<bool?> Function(Duration)? available;
  final PreviewExtractor _extractor;
  final Duration bucket;
  final void Function(Map<String, Object?>)? onDiagnostic;
  final _requested = Stopwatch();
  bool get busy => _busy;
  int get cacheBytes => _bytes;
  void _emit(String event, [Map<String, Object?> data = const {}]) =>
      onDiagnostic?.call({'event': event, ...data});
  final _cache = <(String, int), Uint8List>{};
  final _positions = <(String, int), Duration>{};
  Duration? framePosition;
  final _misses = <(String, int), DateTime>{};
  Timer? _debounce;
  (String, int)? _wanted, _shown;
  bool _busy = false, _closed = false;
  int _bytes = 0, _requestSerial = 0;
  int attempts = 0, hits = 0, failures = 0;
  Duration extractionTime = Duration.zero;

  /// Hold the last image from this video until a replacement is ready.
  void request(Duration? time) {
    if (_closed) return;
    final uri = source();
    final key = time == null || uri == null
        ? null
        : (
            uri,
            time.inMilliseconds ~/
                bucket.inMilliseconds *
                bucket.inMilliseconds,
          );
    if (key == null || (value != null && key.$1 != _shown?.$1)) {
      _clearImage();
    }
    if (key == _wanted) return;
    _debounce?.cancel();
    _wanted = key;
    _requestSerial++;
    _requested
      ..reset()
      ..start();
    if (key == null) {
      return;
    }
    if (value != null && _shown != key) {
      _emit('retained', {
        'target': key.$2 / 1000,
        'previousTarget': _shown!.$2 / 1000,
      });
    }
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      hits++;
      _emit('cache-hit', {
        'target': key.$2 / 1000,
        'entries': _cache.length,
        'cacheBytes': _bytes,
      });
      _shown = key;
      framePosition = _positions[key];
      value = cached;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 180), _run);
  }

  Future<void> _run() async {
    if (_closed || _busy) return;
    if (!allowed()) {
      _emit('skipped', {'reason': 'playback-busy'});
      return;
    }
    final key = _wanted;
    if (key == null || _cache.containsKey(key)) {
      return;
    }
    final miss = _misses[key];
    if (miss != null && DateTime.now().difference(miss).inSeconds < 5) {
      return;
    }
    _busy = true;
    final serial = _requestSerial;
    // The old image stays on screen during the debounce and this check.
    // Unknown coverage must not be treated as an unavailable target.
    bool? present;
    final validation = Stopwatch()..start();
    try {
      present = await available?.call(Duration(milliseconds: key.$2));
    } catch (_) {
      present = null;
    }
    if (_closed || serial != _requestSerial || source() != key.$1) {
      _busy = false;
      if (!_closed && _wanted != null) {
        _debounce = Timer(const Duration(milliseconds: 180), _run);
      }
      return;
    }
    _emit('availability', {
      'target': key.$2 / 1000,
      'available': present,
      'validationMs': validation.elapsedMilliseconds,
    });
    if (present == false) {
      _clearImage();
      _busy = false;
      return;
    }
    if (!allowed()) {
      _busy = false;
      return;
    }
    attempts++;
    final watch = Stopwatch()..start();
    final id = attempts;
    final waitMs = _requested.elapsedMilliseconds;
    _emit('start', {
      'id': id,
      'target': key.$2 / 1000,
      'waitMs': waitMs,
      'bucketMs': bucket.inMilliseconds,
      'retainingPrevious': value != null && _shown != key,
    });
    String? error;
    Uint8List? image;
    try {
      image = await _extractor
          .extract(key.$1, Duration(milliseconds: key.$2))
          .timeout(const Duration(seconds: 3));
    } catch (failure) {
      error = failure.runtimeType.toString();
      // Timeout invalidates the decoder before another request can use it.
      await _extractor.dispose();
    }
    if (image == null) await _extractor.dispose();
    extractionTime += watch.elapsed;
    _emit('end', {
      'id': id,
      'target': key.$2 / 1000,
      'extractionMs': watch.elapsedMilliseconds,
      'requestMs': waitMs + watch.elapsedMilliseconds,
      'success': image != null,
      'displayed':
          !_closed &&
          image != null &&
          _wanted == key &&
          allowed() &&
          source() == key.$1,
      'frameSeconds': _extractor.framePosition?.inMilliseconds == null
          ? null
          : _extractor.framePosition!.inMilliseconds / 1000,
      'imageBytes': image?.length,
      'error': error,
      ..._extractor.timings,
    });
    if (!_closed && image != null && source() == key.$1) {
      while ((_bytes + image.length > 8 * 1024 * 1024 || _cache.length >= 48) &&
          _cache.isNotEmpty) {
        final oldest = _cache.keys.first;
        _positions.remove(oldest);
        final evicted = _cache.remove(oldest)!;
        _bytes -= evicted.length;
        PaintingBinding.instance.imageCache.evict(MemoryImage(evicted));
      }
      if (image.length <= 8 * 1024 * 1024) {
        _cache[key] = image;
        if (_extractor.framePosition case final position?) {
          _positions[key] = position;
        }
        _bytes += image.length;
      }
      if (_wanted == key && allowed()) {
        _shown = key;
        framePosition = _extractor.framePosition;
        value = image;
      }
    } else {
      failures++;
      if (_misses.length >= 128) _misses.remove(_misses.keys.first);
      _misses[key] = DateTime.now();
    }
    _busy = false;
    if (!_closed && _wanted != key) {
      _debounce = Timer(const Duration(milliseconds: 180), _run);
    }
  }

  void _clearImage() {
    _shown = null;
    framePosition = null;
    value = null;
  }

  @override
  void dispose() {
    _closed = true;
    _debounce?.cancel();
    for (final image in _cache.values) {
      PaintingBinding.instance.imageCache.evict(MemoryImage(image));
    }
    _cache.clear();
    _positions.clear();
    _extractor.dispose().ignore();
    super.dispose();
  }
}
