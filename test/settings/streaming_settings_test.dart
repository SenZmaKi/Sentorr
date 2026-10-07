import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/settings/models.dart';

void main() {
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
