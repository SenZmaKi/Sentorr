import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/player/handoff_settings.dart';
import 'package:sentorr/player/track_selection.dart';
import 'package:sentorr/settings/playback_preferences.dart';
import 'package:sentorr/player/stream/audio_tracks.dart';
import 'package:sentorr/player/stream/subtitles.dart';

import 'audio_tracks_test.dart' show AudioPlayer;
import 'subtitles_test.dart' show CaptionPlayer;
import '../support/fake_playback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const intent = HandoffSettings(
    volume: 37,
    speed: 1.25,
    item: ItemPlaybackPreferences(
      audio: TrackPreference('2', 'Japanese', 'jpn'),
      subtitle: TrackPreference('3', 'English SDH', 'eng'),
      captionsEnabled: true,
    ),
  );
  test('handoff merges only this title and current playback controls', () {
    final decoded = HandoffSettings.decode(intent.toJson())!;
    final local = PlaybackPreferences(
      items: {'other': const ItemPlaybackPreferences(captionsEnabled: false)},
    );
    final next = decoded.applyTo(local, 'movie');
    expect(next.volume, 37);
    expect(next.speed, 1.25);
    expect(next.items['movie']!.subtitle!.title, 'English SDH');
    expect(next.items['other'], same(local.items['other']));
    expect(HandoffSettings.decode(null), isNull);
  });
  test('rejects invalid transferred speed and volume', () {
    for (final fields in [
      {'speed': 0},
      {'speed': double.nan},
      {'volume': 101},
    ]) {
      expect(
        () => HandoffSettings.decode({...intent.toJson(), ...fields}),
        throwsFormatException,
      );
    }
  });
  test('automatic audio transfers the track mpv actually selected', () async {
    final selected = await resolveAudioSelection(AudioTrack.auto(), const [
      AudioTrack('1', 'English', 'eng'),
      AudioTrack('2', 'Japanese', 'jpn'),
    ], readNativeId: () async => '1');
    expect(selected?.title, 'English');
    expect(selected?.id, '1');
    final muted = await resolveAudioSelection(
      AudioTrack.no(),
      const [],
      readNativeId: () async => '1',
    );
    expect(muted?.id, 'no');
  });

  test(
    'audio restore matches description when native IDs differ on receiver',
    () async {
      final native = AudioPlayer();
      final player = Player(platformPlayer: native);
      final audio = PlaybackAudio(
        player,
        preferredLanguage: () => 'English',
        saved: () => intent.item.audio,
      );
      audio.opened();
      native.tracks(const [
        AudioTrack('2', 'English', 'eng'),
        AudioTrack('7', 'Japanese', 'jpn'),
      ]);
      await settlePlayback();
      expect(native.selected.last.id, '7');
      audio.dispose();
      await player.dispose();
    },
  );
  test(
    'sidecar text is restored without persisting the text as a track ID',
    () async {
      final native = CaptionPlayer();
      final player = Player(platformPlayer: native);
      var saved = false;
      final captions = PlaybackSubtitles(
        player,
        onChoose: ({subtitle, enabled}) {
          saved = true;
        },
      );
      captions.opened();
      captions.restoreExternal(
        '1\n00:00:00,000 --> 00:00:04,000\nHello\n',
        title: 'English',
        enabled: true,
      );
      await settlePlayback();
      expect(native.selected.last.data, true);
      expect(native.selected.last.id, contains('Hello'));
      expect(captions.enabled, true);
      expect(saved, false);
      captions.off();
      expect(captions.visible, false);
      captions.dispose();
      await player.dispose();
    },
  );
}
