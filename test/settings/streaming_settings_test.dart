import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/settings/models.dart';

void main() {
  test('subtitle language persists and older settings accept any language', () {
    expect(StreamingSettings.fromJson({}).subtitleLanguage, '');
    expect(
      StreamingSettings.fromJson({'subtitleLanguage': 3}).subtitleLanguage,
      '',
    );
    final saved = const StreamingSettings()
        .copyWith(subtitleLanguage: 'Croatian')
        .copyWith(captionsEnabled: true);
    expect(
      StreamingSettings.fromJson(saved.toJson()).subtitleLanguage,
      'Croatian',
    );
    expect(saved.copyWith(subtitleLanguage: '').subtitleLanguage, '');
  });

  test('clock format survives serialization and unrelated edits', () {
    expect(StreamingSettings.fromJson({}).showRemainingTime, isFalse);
    final restored = StreamingSettings.fromJson(
      const StreamingSettings()
          .copyWith(showRemainingTime: true)
          .copyWith(keepRecentTorrents: 4)
          .toJson(),
    );
    expect(restored.showRemainingTime, isTrue);
  });
  test('resume rewind defaults, custom values and Disabled persist', () {
    expect(StreamingSettings.fromJson({}).resumeRewindSeconds, 5);
    for (final seconds in [0, 17]) {
      final saved = const StreamingSettings()
          .copyWith(resumeRewindSeconds: seconds)
          .copyWith(keepRecentTorrents: 4);
      final restored = StreamingSettings.fromJson(saved.toJson());
      expect(restored.resumeRewindSeconds, seconds);
      expect(
        restored.resumePosition(const Duration(seconds: 30)),
        Duration(seconds: 30 - seconds),
      );
      expect(restored.resumePosition(Duration.zero), Duration.zero);
    }
    for (final invalid in [-1, '10', null]) {
      expect(
        StreamingSettings.fromJson({'resumeRewindSeconds': invalid})
            .resumeRewindSeconds,
        5,
      );
    }
  });

  test('caption default is off and survives unrelated settings edits', () {
    expect(AppSettings.fromJson({}).streaming.captionsEnabled, isFalse);
    final settings = const StreamingSettings()
        .copyWith(captionsEnabled: true)
        .copyWith(keepRecentTorrents: 4);
    final restored = AppSettings.fromJson(
      AppSettings(streaming: settings).toJson(),
    );
    expect(restored.streaming.captionsEnabled, isTrue);
    expect(
      StreamingSettings.fromJson({'captionsEnabled': 'true'}).captionsEnabled,
      isFalse,
    );
  });
  test('player buffers default to 128/32 MiB and persist custom values', () {
    final defaults = StreamingSettings.fromJson({});
    expect(defaults.playerForwardBufferMiB, 128);
    expect(defaults.playerBackwardBufferMiB, 32);
    final restored = StreamingSettings.fromJson(
      defaults
          .copyWith(playerForwardBufferMiB: 256, playerBackwardBufferMiB: 0)
          .copyWith(downloadAheadMinutes: 15)
          .toJson(),
    );
    expect(restored.playerForwardBufferMiB, 256);
    expect(restored.playerBackwardBufferMiB, 0);
    final invalid = StreamingSettings.fromJson({
      'playerForwardBufferMiB': 0,
      'playerBackwardBufferMiB': -1,
    });
    expect(invalid.playerForwardBufferMiB, 128);
    expect(invalid.playerBackwardBufferMiB, 32);
  });
  test('time buffer defaults and unlimited choice survive settings edits', () {
    final defaults = StreamingSettings.fromJson({'readAheadBytes': 999});
    expect(defaults.downloadAheadMinutes, 10);
    expect(defaults.limitDownloadAhead, true);
    final changed = defaults
        .copyWith(downloadAheadMinutes: 17, limitDownloadAhead: false)
        .copyWith(keepRecentTorrents: 4);
    final restored = StreamingSettings.fromJson(changed.toJson());
    expect(restored.downloadAheadMinutes, 17);
    expect(restored.limitDownloadAhead, false);
    expect(
      StreamingSettings.fromJson({'downloadAheadMinutes': -1})
          .downloadAheadMinutes,
      10,
    );
  });
  test('focus pausing defaults on for new and existing settings', () {
    expect(const StreamingSettings().pauseOnFocusLoss, isTrue);
    expect(AppSettings.fromJson({}).streaming.pauseOnFocusLoss, isTrue);
    expect(
      StreamingSettings.fromJson({'pauseOnFocusLoss': 'invalid'})
          .pauseOnFocusLoss,
      isTrue,
    );
  });
  test('disabling focus pausing survives saving and other edits', () {
    final settings = const StreamingSettings()
        .copyWith(pauseOnFocusLoss: false)
        .copyWith(keepRecentTorrents: 4);
    final restored = AppSettings.fromJson(
      AppSettings(streaming: settings).toJson(),
    );
    expect(restored.streaming.pauseOnFocusLoss, isFalse);
    expect(restored.streaming.keepRecentTorrents, 4);
  });
}
