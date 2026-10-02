import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'engine_client.dart';
import 'streaming_profile.dart';
import 'playback_monitor.dart';
import '../engine/streaming_policy.dart';

class LabController extends ChangeNotifier {
  LabController() {
    _muteReady = player.setVolume(0);
    monitor = PlaybackMonitor(player, notifyListeners);
    _subscriptions.add(
      engine.events.listen((event) {
        if (event['event'] == 'snapshot') {
          snapshot = event;
        } else {
          record(event);
        }
        notifyListeners();
      }),
    );
    _subscriptions.add(
      player.stream.error.listen((message) {
        error = message;
        record({'event': 'player-error', 'message': message});
        notifyListeners();
      }),
    );
    _subscriptions.add(
      player.stream.buffering.listen((value) {
        bufferingSinceMs = value ? clock.elapsedMilliseconds : null;
        record({
          'event': 'player-buffering',
          'value': value,
          'positionMs': player.state.position.inMilliseconds,
        });
        notifyListeners();
      }),
    );
    _subscriptions.add(player.stream.position.listen((_) => notifyListeners()));
    _subscriptions.add(player.stream.playing.listen((_) => notifyListeners()));
  }
  StreamingProfile profile = StreamingProfile.environment();
  bool muted = true;
  late final Future<void> _muteReady;
  late final PlaybackMonitor monitor;
  int? bufferingSinceMs;
  final engine = EngineClient();
  final player = Player(
    configuration: const PlayerConfiguration(
      title: 'Sentorr Streaming Lab',
      libass: true,
      bufferSize: 64 * 1024 * 1024,
    ),
  );
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final events = <Map<String, Object?>>[];
  final clock = Stopwatch()..start();
  List<Map<String, Object?>> files = [];
  Map<String, Object?> snapshot = {};
  int? selected;
  String? error;
  bool busy = false, active = false, controlled = false;
  bool transferPaused = false, seedPaused = false;
  String source = '';

  void record(Map<String, Object?> event) {
    events.add({'elapsedMs': clock.elapsedMilliseconds, ...event});
    if (events.length > 1000) events.removeAt(0);
  }

  Future<void> open(String input, {bool localSeed = false}) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await player.stop();
      await engine.command('close');
      active = false;
      files = [];
      snapshot = {};
      events.clear();
      clock.reset();
      controlled = localSeed;
      source = input;
      transferPaused = seedPaused = false;
      final result = await engine.command('open', {
        'input': input,
        'controlled': localSeed,
        ...profile.toJson(),
      });
      files = (result as List)
          .map((f) => Map<String, Object?>.from(f as Map))
          .toList();
      final candidates = files
          .where(
            (f) =>
                (f['size'] as int) > 0 &&
                ((f['flags'] as int) & 1) == 0 &&
                RegExp(
                  r'\.(mp4|mkv|webm|avi|mov|m4v|ts)$',
                  caseSensitive: false,
                ).hasMatch(f['path'] as String),
          )
          .toList();
      candidates.sort((a, b) => (b['size'] as int).compareTo(a['size'] as int));
      selected = candidates.isEmpty ? null : candidates.first['index'] as int;
      record({
        'event': 'metadata-ready',
        'files': files.length,
        'controlled': controlled,
      });
      if (localSeed && selected != null) await _play();
    } catch (e) {
      error = '$e';
      record({'event': 'error', 'message': '$e'});
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> playSelected() async {
    if (busy || active || selected == null) return;
    busy = true;
    notifyListeners();
    try {
      await _play();
    } catch (e) {
      error = '$e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _play() async {
    final uri = await engine.command('select', {'index': selected});
    record({'event': 'player-open', 'fileIndex': selected});
    // Cancel old HTTP demands before the player opens the source at a new offset.
    await _muteReady;
    await player.setVolume(muted ? 0 : 100);
    final native = player.platform;
    if (native is NativePlayer) {
      for (final entry in <String, String>{
        'network-timeout': '${StreamingPolicy.networkTimeoutSeconds}',
        'cache': 'yes',
        'cache-secs': '${profile.bufferSeconds}',
        'cache-pause': 'yes',
        'cache-pause-initial': 'yes',
        'cache-pause-wait': '${profile.resumeSeconds}',
        'demuxer-max-bytes': '${64 * 1024 * 1024}',
        'demuxer-max-back-bytes': '${16 * 1024 * 1024}',
      }.entries) {
        await native.setProperty(entry.key, entry.value);
      }
    }
    record({
      'event': 'playback-profile',
      ...profile.toJson(),
      'networkTimeoutSeconds': '${StreamingPolicy.networkTimeoutSeconds}',
      'tcpOnly': StreamingPolicy.tcpOnly,
      'bootstrap': StreamingPolicy.bootstrap,
      'narrowUrgent': StreamingPolicy.narrowUrgent,
    });
    monitor.start();
    await player.open(Media(uri as String));
    active = true;
  }

  Future<void> seek(Duration position) async {
    if (!active) return;
    record({'event': 'seek', 'targetMs': position.inMilliseconds});
    await engine.command('seek');
    await player.seek(position);
  }

  Future<void> toggleMute() async {
    muted = !muted;
    await _muteReady;
    await player.setVolume(muted ? 0 : 100);
    notifyListeners();
  }

  Future<void> togglePlayback() async {
    record({'event': 'playback-pause', 'paused': player.state.playing});
    await player.playOrPause();
  }

  Future<void> toggleTransfer() async {
    await engine.command('pause-transfer', {'paused': !transferPaused});
    transferPaused = !transferPaused;
    notifyListeners();
  }

  Future<void> toggleSeed() async {
    await engine.command('pause-seed', {'paused': !seedPaused});
    seedPaused = !seedPaused;
    notifyListeners();
  }

  Future<void> stop() async {
    busy = true;
    notifyListeners();
    try {
      await player.stop();
      await engine.command('close');
      active = false;
      files = [];
      selected = null;
      record({'event': 'stop'});
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Map<String, Object?> report() => {
    'schemaVersion': 1,
    'profile': profile.toJson(),
    'muted': muted,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'controlled': controlled,
    'source': source,
    'selected': selected,
    'files': files,
    'snapshot': snapshot,
    'events': events,
    'player': {
      'positionMs': player.state.position.inMilliseconds,
      'durationMs': player.state.duration.inMilliseconds,
      'bufferMs': player.state.buffer.inMilliseconds,
      'buffering': player.state.buffering,
    },
    'error': error,
  };
  Future<void> export(String path) =>
      File(path)
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report()));
  Future<void>? _shutdown;
  Future<void> shutdown() => _shutdown ??= _close();
  Future<void> _close() async {
    monitor.close();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await player.stop();
    await engine.dispose();
    await player.dispose();
    clock.stop();
    super.dispose();
  }
}
