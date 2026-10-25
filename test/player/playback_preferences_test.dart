import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:torrent_stream/torrent_stream.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/settings/playback_preferences.dart';
import 'package:sentorr/settings/repository.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/player/stream/audio_tracks.dart';
import 'package:sentorr/player/stream/subtitles.dart';

import 'audio_tracks_test.dart' show AudioPlayer;
import 'subtitles_test.dart' show CaptionPlayer;
import '../support/fake_playback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'missing saved audio falls back to language without reusing its ID',
    () async {
      final native = AudioPlayer();
      final player = Player(platformPlayer: native);
      final audio = PlaybackAudio(
        player,
        preferredLanguage: () => 'Japanese',
        saved: () => const TrackPreference('2', 'Commentary', 'eng'),
      );
      audio.opened();
      native.tracks(const [
        AudioTrack('2', 'French', 'fra'),
        AudioTrack('7', 'Main', 'jpn'),
      ]);
      await settlePlayback();
      expect(native.selected.last.id, '7');
      audio.dispose();
      await player.dispose();
    },
  );

  test(
    'caption intent belongs to each item after switching and returning',
    () async {
      var item = 'movie';
      var preferences = const PlaybackPreferences();
      final native = CaptionPlayer();
      final player = Player(platformPlayer: native);
      final captions = PlaybackSubtitles(
        player,
        defaultEnabled: false,
        saved: () => preferences.items[item],
        onChoose: ({subtitle, enabled}) {
          preferences = preferences.updateItem(
            item,
            (p) => p.copyWith(subtitle: subtitle, captionsEnabled: enabled),
          );
        },
      );
      captions.opened();
      captions.chooseTrack(const SubtitleTrack('3', 'English SDH', 'eng'));
      await settlePlayback();
      await captions.reset();
      item = 'episode';
      captions.opened();
      expect(captions.enabled, false);
      captions.on();
      captions.off();
      await captions.reset();
      item = 'movie';
      captions.opened();
      expect(captions.enabled, true);
      expect(preferences.items['movie']!.subtitle!.title, 'English SDH');
      expect(preferences.items['episode']!.captionsEnabled, false);
      captions.dispose();
      await player.dispose();
    },
  );

  test(
    'saved sidecar restores by filename when torrent file indices change',
    () async {
      final native = CaptionPlayer();
      final player = Player(platformPlayer: native);
      final captions = PlaybackSubtitles(
        player,
        defaultEnabled: false,
        saved: () => const ItemPlaybackPreferences(
          captionsEnabled: true,
          subtitle: TrackPreference('1', 'Movie.en', null, file: true),
        ),
      );
      captions.files = const [
        SubtitleDownload(
          TorrentStreamFile(
            index: 9,
            path: 'Movie.en.srt',
            length: 100,
            isPadFile: false,
          ),
        ),
      ];
      captions.opened();
      expect(captions.selectedFile, 9);
      expect(captions.visible, false);
      captions.dispose();
      await player.dispose();
    },
  );

  test(
    'old settings get playback defaults and invalid numbers are bounded',
    () {
      final old = AppSettings.fromJson({});
      expect(old.streaming.playback.volume, 100);
      expect(old.streaming.playback.speed, 1);
      final bounded = PlaybackPreferences.fromJson({
        'volume': -12,
        'speed': 50,
      });
      expect(bounded.volume, 0);
      expect(bounded.speed, 2);
      final invalid = PlaybackPreferences.fromJson({
        'volume': double.nan,
        'speed': 'fast',
      });
      expect(invalid.volume, 100);
      expect(invalid.speed, 1);
    },
  );

  test('fresh repository restores playback preferences from disk', () async {
    final directory = await Directory.systemTemp.createTemp(
      'playback-settings',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/settings.json');
    final preferences = const PlaybackPreferences(volume: 37, speed: 1.5)
        .updateItem(
          'movie',
          (p) => p.copyWith(
            audio: const TrackPreference('2', 'Commentary', 'eng'),
            subtitle: const TrackPreference('4', 'English SDH', 'eng'),
            captionsEnabled: false,
          ),
        );
    await SettingsRepository(JsonFileStore(file))
        .save(AppSettings(streaming: StreamingSettings(playback: preferences)));
    final restored = await SettingsRepository(JsonFileStore(file)).load();
    expect(restored.streaming.playback.toJson(), preferences.toJson());
    expect(PlaybackPreferences.fromJson(null).volume, 100);
  });

  test(
    'audio choice survives controller recreation and changed track IDs',
    () async {
      TrackPreference? saved;
      final firstNative = AudioPlayer();
      final first = Player(platformPlayer: firstNative);
      final audio = PlaybackAudio(
        first,
        preferredLanguage: () => '',
        onChoose: (track) => saved = track,
      );
      audio.choose(const AudioTrack('2', 'Commentary', 'eng'));
      await settlePlayback();
      audio.dispose();
      await first.dispose();
      final native = AudioPlayer();
      final player = Player(platformPlayer: native);
      final restored = PlaybackAudio(
        player,
        preferredLanguage: () => '',
        saved: () => saved,
      );
      restored.opened();
      native.tracks(const [
        AudioTrack('2', 'Main', 'jpn'),
        AudioTrack('5', 'Commentary', 'eng'),
      ]);
      await settlePlayback();
      expect(native.selected.last.id, '5');
      restored.dispose();
      await player.dispose();
    },
  );

  test(
    'saved caption selection overrides default and Off survives reopening',
    () async {
      var saved = const ItemPlaybackPreferences(
        subtitle: TrackPreference('2', 'English SDH', 'eng'),
        captionsEnabled: true,
      );
      final native = CaptionPlayer();
      final player = Player(platformPlayer: native);
      final captions = PlaybackSubtitles(
        player,
        defaultEnabled: false,
        saved: () => saved,
        onChoose: ({subtitle, enabled}) => saved = saved.copyWith(
          subtitle: subtitle,
          captionsEnabled: enabled,
        ),
      );
      captions.opened();
      native.state = native.state.copyWith(
        tracks: const Tracks(
          subtitle: [
            SubtitleTrack('2', 'French', 'fra'),
            SubtitleTrack('6', 'English SDH', 'eng'),
          ],
        ),
      );
      native.emitTracks();
      await settlePlayback();
      expect(native.selected.last.id, '6');
      captions.off();
      await captions.reset();
      captions.opened();
      await settlePlayback();
      expect(captions.enabled, false);
      captions.dispose();
      await player.dispose();
    },
  );
}
