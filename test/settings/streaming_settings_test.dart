import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/settings/models.dart';

void main() {
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
