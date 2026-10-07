import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/progress_tracker.dart';

import '../support/fake_playback.dart';

const _hour = Duration(hours: 1);
final _movie = PlaybackItem(
  title: ImdbTitle(id: 'tt1', title: 'Movie'),
);
final _other = PlaybackItem(
  title: ImdbTitle(id: 'tt2', title: 'Other'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePlayback native;
  late Player player;
  late ProgressTracker tracker;
  late List<(String, Duration)> saved;
  late PlaybackItem? streaming;

  /// Moves the player as mpv would: state first, then the event.
  Future<void> at(Duration position, {bool? playing}) async {
    native.state = native.state.copyWith(
      position: position,
      duration: _hour,
      playing: playing ?? native.state.playing,
    );
    if (playing != null) native.emitPlaying(playing);
    native.emitPosition(position);
    await settlePlayback();
  }

  setUp(() {
    native = FakePlayback();
    player = Player(platformPlayer: native);
    saved = [];
    streaming = _movie;
    tracker = ProgressTracker(
      player,
      canRecord: (item) => streaming?.id == item.id,
      save: (item, position, _) => saved.add((item.id, position)),
    )..item = _movie;
  });
  tearDown(() async {
    await tracker.dispose();
    await player.dispose();
  });

  test('pausing saves where playback stopped', () async {
    await at(const Duration(minutes: 5), playing: true);
    await at(const Duration(minutes: 6), playing: false);
    expect(saved, [('tt1', const Duration(minutes: 6))]);
  });

  test('a seek while paused is saved once it settles', () async {
    await at(const Duration(minutes: 5), playing: false);
    saved.clear();
    await at(const Duration(minutes: 20));
    await at(const Duration(minutes: 30));
    expect(saved, isEmpty);
    await Future<void>.delayed(
      ProgressTracker.seekSettle + const Duration(milliseconds: 100),
    );
    expect(saved, [('tt1', const Duration(minutes: 30))]);
  });

  test('switching items saves the previous one first', () async {
    await at(const Duration(minutes: 5), playing: true);
    tracker.item = _other;
    expect(saved, [('tt1', const Duration(minutes: 5))]);
  });

  test('the old stream stopping is not saved as the next item', () async {
    await at(const Duration(minutes: 40), playing: true);
    tracker.item = _other;
    saved.clear();
    // The player still holds the previous item's position as it stops.
    await at(const Duration(minutes: 40), playing: false);
    expect(saved, isEmpty);
    streaming = _other;
    await at(const Duration(minutes: 2), playing: true);
    await at(const Duration(minutes: 3), playing: false);
    expect(saved, [('tt2', const Duration(minutes: 3))]);
  });

  test('nothing is saved before playback has a position', () async {
    await at(Duration.zero, playing: true);
    await at(Duration.zero, playing: false);
    expect(saved, isEmpty);
  });
}
