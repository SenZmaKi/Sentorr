import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/layout.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/sync/copies.dart';
import 'package:sentorr/sync/peers.dart';
import 'package:sentorr/torrents/models.dart';

import '../support/fake_imdb.dart';
import 'harness.dart';

final _series = fakeTitle(2, series: true);
final _release = TorrentRelease(
  source: TorrentSourceId.values.first,
  name: 'Show S01',
  infoHash: 'b' * 40,
  magnet: Uri.parse('magnet:?xt=urn:btih:${'b' * 40}'),
  seeders: 10,
  sizeBytes: 1000,
  isSeasonPack: true,
);

PlaybackItem _episode(int n) => PlaybackItem(
  title: ImdbTitle(id: 'tt10$n', title: 'Episode $n'),
  series: _series,
  season: 1,
  episode: n,
);

List<int> _bytes(int n) => List.generate(200000 + n, (i) => (i * n) % 253);

void main() {
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sentorr_copy');
    addTearDown(() => temp.delete(recursive: true));
  });

  /// A laptop sharing episodes 1 and 2, paired with a phone that has none.
  Future<(ProviderContainer, ProviderContainer)> devices() async {
    final shared = [
      for (final n in [1, 2])
        () {
          final file = File(p.join(temp.path, 'laptop', 'E$n.mkv'))
            ..createSync(recursive: true)
            ..writeAsBytesSync(_bytes(n));
          return LibraryEntry(
            item: _episode(n),
            downloadId: 'd$n',
            release: _release,
            fileIndex: n,
            path: file.path,
            addedAt: DateTime(2026),
          );
        }(),
    ];
    final laptop = await syncDevice('Laptop', library: shared);
    final phone = await syncDevice(
      'Phone',
      overrides: [
        downloadsDirectoryProvider.overrideWithValue(
          p.join(temp.path, 'phone'),
        ),
      ],
    );
    await pair(laptop, phone);
    await phone.read(peersProvider.notifier).syncWith(idOf(laptop));
    return (laptop, phone);
  }

  test(
    'copies a season\'s episodes a paired device has, resuming one',
    () async {
      final (_, phone) = await devices();
      final copies = phone.read(peerCopiesProvider);
      final offer = copies.offer((i) => i.series?.id == _series.id);
      expect(offer.ids, {'tt101', 'tt102'});
      expect(offer.devices, 'Laptop');

      // Episode 2 was half copied before.
      final second = layoutFor(
        _episode(2),
        p.join(temp.path, 'phone'),
        'E2.mkv',
      );
      final target = p.join(second.directory, second.name);
      File('$target.part')
        ..createSync(recursive: true)
        ..writeAsBytesSync(_bytes(2).sublist(0, 50000));

      copies.start(offer);
      expect(
        phone.read(offlineStateProvider('tt101')),
        isA<Downloading>().having((s) => s.from, 'from', 'Laptop'),
      );
      // Offered once: what is copying is not offered again.
      expect(copies.offer((i) => i.series?.id == _series.id).isEmpty, true);

      await until(() => phone.read(libraryProvider).length == 2);
      for (final n in [1, 2]) {
        final entry = phone.read(libraryProvider.notifier).entry('tt10$n')!;
        expect(File(entry.path).readAsBytesSync(), _bytes(n));
        expect(entry.downloadId, startsWith('copy:'));
        expect(entry.release.infoHash, _release.infoHash);
        expect(entry.fileIndex, n);
        expect(phone.read(offlineStateProvider('tt10$n')), isA<Downloaded>());
      }
      expect(
        File(target).path,
        endsWith(p.join('Season 01', 'Title 2 S01E02.mkv')),
      );
      expect(File('$target.part').existsSync(), false);
      expect(phone.read(copyingProvider), isEmpty);
    },
  );

  test('a cancelled copy leaves nothing behind', () async {
    final (_, phone) = await devices();
    final copies = phone.read(peerCopiesProvider);
    copies.start(copies.offer((i) => i.id == 'tt101'));
    await copies.cancel('tt101');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(phone.read(libraryProvider), isEmpty);
    expect(phone.read(copyingProvider), isEmpty);
    expect(
      Directory(p.join(temp.path, 'phone')).existsSync()
          ? Directory(p.join(temp.path, 'phone'))
                .listSync(recursive: true)
                .whereType<File>()
          : const <File>[],
      isEmpty,
    );
  });

  test('an automatic download copies without asking', () async {
    final (_, phone) = await devices();
    final copies = phone.read(peerCopiesProvider);
    expect(copies.copyIfOffered(_episode(1), automatic: true), true);
    expect(copies.copyIfOffered(_episode(3), automatic: true), false);
    await until(() => phone.read(libraryProvider).length == 1);
    expect(phone.read(libraryProvider).single.automatic, true);
  });
}
