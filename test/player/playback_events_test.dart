import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/playback_events.dart';

void main() {
  late DateTime now;
  late PlaybackEvents events;
  void advance(int ms) => now = now.add(Duration(milliseconds: ms));
  List<String> kinds() =>
      events.between(DateTime(2000)).map((e) => e.kind).toList();
  Map<String, Object?> last(String kind) =>
      events.between(DateTime(2000)).lastWhere((e) => e.kind == kind).data;

  setUp(() {
    now = DateTime(2026, 10, 15, 12);
    events = PlaybackEvents(clock: () => now);
  });

  test('an open is ready once the playhead advances while playing', () {
    events.opened({'itemId': 'tt1'}, Duration.zero);
    events.playing(true);
    events.buffering(true);
    advance(3000);
    events.buffering(false);
    events.position(const Duration(seconds: 40)); // the landing jump
    advance(250);
    events.position(const Duration(milliseconds: 40250));
    expect(kinds(), ['open', 'play', 'ready']);
    expect(last('ready'), containsPair('after', 'open'));
    expect(last('ready')['ms'], 3250);
  });

  test('a seek is timed on its own and is not a stall', () {
    events.playing(true);
    events.seeking(const Duration(seconds: 10), const Duration(seconds: 600));
    events.buffering(true);
    advance(1200);
    events.buffering(false);
    events.position(const Duration(seconds: 600));
    advance(200);
    events.position(const Duration(milliseconds: 600200));
    expect(kinds(), ['play', 'seek', 'ready']);
    expect(last('ready'), {
      'after': 'seek',
      'ms': 1400,
      'positionSeconds': 600.2,
    });
  });

  test('buffering during playback is a stall with its length', () {
    events.playing(true);
    events.buffering(true);
    advance(4500);
    events.buffering(false);
    expect(kinds(), ['play', 'stall', 'stall-end']);
    expect(last('stall-end'), {'ms': 4500});
  });

  test('stage changes are timed from the open', () {
    events.opened({}, Duration.zero);
    advance(800);
    events.stage('stage', {'stage': 'streaming'});
    expect(last('stage'), {'stage': 'streaming', 'sinceOpenMs': 800});
  });

  test('old events fall out of the window', () {
    events = PlaybackEvents(clock: () => now, keep: const Duration(minutes: 1));
    events.add('old');
    advance(61000);
    events.add('new');
    expect(kinds(), ['new']);
    expect(
      events.between(now.subtract(const Duration(seconds: 1))),
      hasLength(1),
    );
  });
}
