import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/settings/streaming_settings.dart';
import 'package:sentorr/player/recovery.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/watching/models.dart';

void main() {
  late Directory root;
  late PlaybackRecovery recovery;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sentorr-recovery-');
    recovery = PlaybackRecovery(
      JsonFileStore(File('${root.path}/playback.json')),
    );
  });
  tearDown(() => root.delete(recursive: true));

  WatchEntry entry(int seconds) => WatchEntry.of(
    PlaybackItem(
      title: ImdbTitle(id: 'episode', title: 'Episode'),
      series: ImdbTitle(id: 'series', title: 'Series'),
      season: 2,
      episode: 7,
    ),
    position: Duration(seconds: seconds),
    duration: const Duration(minutes: 40),
  );

  test('restart retains exact episode and rewinds five seconds', () async {
    await recovery.save(entry(123));
    final restarted = PlaybackRecovery(JsonFileStore(recovery.store.file));
    final saved = (await restarted.load())!;
    expect(saved.item.id, 'episode');
    expect(saved.item.series!.id, 'series');
    expect(saved.item.season, 2);
    expect(saved.item.episode, 7);
    expect(PlaybackRecovery.start(saved), const Duration(seconds: 118));
    expect(PlaybackRecovery.start(entry(3)), Duration.zero);
    expect(
      PlaybackRecovery.start(
        saved,
        settings: const StreamingSettings(resumeRewindSeconds: 12),
      ),
      const Duration(seconds: 111),
    );
    expect(
      PlaybackRecovery.start(
        saved,
        settings: const StreamingSettings(resumeRewindSeconds: 0),
      ),
      saved.position,
    );
  });

  test('flush checkpoints latest position before exit', () async {
    await recovery.save(entry(10));
    recovery.checkpoint = () => recovery.save(entry(98));
    await recovery.flush();
    expect((await recovery.load())!.position, const Duration(seconds: 98));
  });

  test(
    'explicit close remains cleared after pending saves and restart',
    () async {
      final pending = recovery.save(entry(60));
      await recovery.save(null);
      await pending;
      expect(
        await PlaybackRecovery(JsonFileStore(recovery.store.file)).load(),
        isNull,
      );
    },
  );
}
