import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/player/stream/audio_tracks.dart';

import '../support/fake_playback.dart';

class AudioPlayer extends FakePlayback {
  final selected = <AudioTrack>[];
  void tracks(List<AudioTrack> audio) {
    state = state.copyWith(tracks: Tracks(audio: audio));
    tracksController.add(state.tracks);
  }

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    selected.add(track);
    state = state.copyWith(track: state.track.copyWith(audio: track));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'late discovery respects language, manual choice and file reset',
    () async {
      final native = AudioPlayer();
      final player = Player(platformPlayer: native);
      var preference = 'Japanese';
      final audio = PlaybackAudio(player, preferredLanguage: () => preference);
      const english = AudioTrack('1', 'Commentary', 'eng');
      const japanese = AudioTrack('2', null, 'jpn');
      audio.opened();
      native.tracks([english]);
      await settlePlayback();
      expect(native.selected, isEmpty);
      native.tracks([english, japanese]);
      await settlePlayback();
      expect(native.selected.last, japanese);
      audio.choose(english);
      native.tracks([english, japanese]);
      await settlePlayback();
      expect(native.selected.last, english);
      await audio.reset();
      native.tracks([english, japanese]);
      await settlePlayback();
      expect(native.selected.last.id, 'auto');
      audio.opened();
      await settlePlayback();
      expect(native.selected.last, japanese);
      await audio.reset();
      preference = '';
      audio.opened();
      native.tracks([english, japanese]);
      await settlePlayback();
      expect(native.selected.last.id, 'auto');
      audio.dispose();
      await player.dispose();
    },
  );
}
