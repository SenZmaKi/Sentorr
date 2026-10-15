import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/playback_events.dart';
import 'package:sentorr/player/stats_recording.dart';

void main() {
  final start = DateTime(2026, 10, 15, 12);
  DateTime at(int s) => start.add(Duration(seconds: s));

  test('native readouts become typed values', () {
    expect(StatsRecording.typed('23.976'), 23.976);
    expect(StatsRecording.typed('12'), 12);
    expect(StatsRecording.typed('h264'), 'h264');
    expect(StatsRecording.typed('Unavailable'), isNull);
    expect(StatsRecording.typed(''), isNull);
    expect(StatsRecording.typed(null), isNull);
  });

  test('exports session, summary, changes and one sample per line', () {
    final recording = StatsRecording(startedAt: start)
      ..add({'drops': 2, 'state': 'playing'}, at: at(0))
      ..add({'drops': 5, 'state': 'buffering', 'peers': 4}, at: at(1))
      ..add({'drops': 3, 'state': 'playing'}, at: at(2))
      ..stop(at: at(3));
    recording.add({'drops': 99});

    final text = recording.toJson(extra: {'platform': 'macos'});
    final json = jsonDecode(text) as Map<String, dynamic>;
    expect(json['session'], {'platform': 'macos'});
    expect(json['durationSeconds'], 3);
    expect(json['sampleCount'], 3);
    expect(json['segments'].single['summary']['drops'], {
      'first': 2,
      'last': 3,
      'min': 2,
      'max': 5,
    });
    expect(json['changes'], [
      {'t': 1, 'metric': 'state', 'from': 'playing', 'to': 'buffering'},
      {'t': 2, 'metric': 'state', 'from': 'buffering', 'to': 'playing'},
    ]);
    expect(json['samples'][1], {
      't': 1,
      'segment': 0,
      'drops': 5,
      'state': 'buffering',
      'peers': 4,
    });
    expect(text, contains('    {"t":1.0,"segment":0,"drops":5,'));
  });

  test('a new source starts a segment with its own details and summary', () {
    final recording = StatsRecording(startedAt: start)
      ..add({'drops': 10}, segmentKey: 'a', segment: {'file': null}, at: at(0))
      ..add(
        {'drops': 12},
        segmentKey: 'a',
        segment: {'file': 'a.mkv'},
        at: at(1),
      )
      ..add(
        {'drops': 0},
        segmentKey: 'b',
        segment: {'file': 'b.mkv'},
        at: at(2),
      )
      ..add({'drops': 1}, segmentKey: 'b', segment: {'file': null}, at: at(3))
      ..stop(at: at(4));

    final json = jsonDecode(recording.toJson()) as Map<String, dynamic>;
    final segments = json['segments'] as List;
    expect(recording.segments, 2);
    expect(segments[0]['file'], 'a.mkv');
    expect(segments[0]['endSeconds'], 2);
    expect(segments[0]['summary']['drops']['last'], 12);
    expect(segments[1]['file'], 'b.mkv');
    expect(segments[1]['startSeconds'], 2);
    expect(segments[1]['summary']['drops'], {
      'first': 0,
      'last': 1,
      'min': 0,
      'max': 1,
    });
    expect([for (final s in json['samples']) s['segment']], [0, 0, 1, 1]);
  });

  test('events land one per line, timed from the start, pre-roll negative', () {
    final recording = StatsRecording(startedAt: start)
      ..add({
        'engine': {'peers': 1},
        'state': 'playing',
      }, at: at(0))
      ..add({
        'engine': {'peers': 2},
        'state': 'playing',
      }, at: at(1))
      ..stop(at: at(2));
    final text = recording.toJson(
      events: [
        PlaybackEvent(at(-30), 'seek', {'toSeconds': 600}),
        PlaybackEvent(at(1), 'stall', {}),
      ],
    );
    final json = jsonDecode(text) as Map<String, dynamic>;
    expect(json['events'], [
      {'t': -30, 'kind': 'seek', 'toSeconds': 600},
      {'t': 1, 'kind': 'stall'},
    ]);
    // Nested engine detail is sampled, not logged as a change.
    expect(json['changes'], isEmpty);
    expect(text, contains('    {"t":-30.0,"kind":"seek","toSeconds":600}'));
  });

  test('an empty recording is still valid JSON', () {
    final recording = StatsRecording()..stop();
    expect(jsonDecode(recording.toJson())['samples'], isEmpty);
  });
}
