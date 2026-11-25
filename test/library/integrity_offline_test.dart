import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/library/integrity.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/shared/net/online.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/parsing.dart';
import 'package:sentorr/torrents/metadata_identity.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../packages/torrent_stream/test/engine_support.dart' as native;
import '../support/fake_download_torrents.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_torrents.dart';

void main() {
  test('torrent metadata is rebuilt from resume state with its info', () {
    final info = utf8.encode('d4:name5:movie12:piece lengthi16384ee');
    final torrent = Uint8List.fromList([
      ...utf8.encode('d8:announce3:url4:info'),
      ...info,
      101,
    ]);
    final hash = sha1.convert(info).toString();
    validateMetadataIdentity(torrent, hash);
    final resume = Uint8List.fromList([
      ...utf8.encode('d11:file-formati1e4:info'),
      ...info,
      ...utf8.encode('6:piecesi0ee'),
    ]);
    final rebuilt = metadataFromResume(resume, hash)!;
    expect(() => validateMetadataIdentity(rebuilt, hash), returnsNormally);
    expect(metadataFromResume(resume, '0' * 40), isNull);
    expect(
      metadataFromResume(Uint8List.fromList(utf8.encode('d1:ai1ee')), hash),
      isNull,
    );
    expect(metadataFromResume(Uint8List.fromList([100, 49]), hash), isNull);
  });

  test('entries remember verification and where their torrent saves', () {
    final show = fakeTitle(2, series: true);
    final episode = LibraryEntry(
      item: PlaybackItem(
        title: fakeTitle(3),
        series: show,
        season: 1,
        episode: 4,
      ),
      downloadId: 'd',
      release: fakeRelease(1),
      fileIndex: 0,
      path: '/root/Show/Season 01/Show S01E04.mkv',
      addedAt: DateTime(2026),
    );
    expect(episode.saveDirectory, '/root/Show');
    expect(episode.savedName, 'Season 01/Show S01E04.mkv');
    final checked = episode.verified(DateTime(2026, 2));
    expect(episode.sameFile(checked), isTrue);
    final restored = LibraryEntry.fromJson(
      jsonDecode(jsonEncode(checked.toJson())),
    )!;
    expect(restored.verifiedAt, DateTime(2026, 2));
    expect(LibraryEntry.fromJson(episode.toJson())!.verifiedAt, isNull);
    final movie = LibraryEntry(
      item: PlaybackItem(title: fakeTitle(1)),
      downloadId: 'd',
      release: fakeRelease(1),
      fileIndex: 0,
      path: '/root/Movie/Movie.mkv',
      addedAt: DateTime(2026),
    );
    expect(movie.saveDirectory, '/root/Movie');
    expect(movie.savedName, 'Movie.mkv');
  });

  test(
    'an episode is verified offline from its download resume state',
    () async {
      final root = await Directory.systemTemp.createTemp('sentorr-offline-');
      final source = File('${root.path}/src/release.mp4');
      await source.create(recursive: true);
      final bytes = Uint8List.fromList(
        List.generate(256 * 1024, (i) => i % 251),
      );
      await source.writeAsBytes(bytes);
      final metadata = createTorrentData(
        sourcePath: source.path,
        pieceSize: 65536,
      );
      final show = Directory('${root.path}/Show');
      final file = File('${show.path}/Season 01/Show S01E01.mp4');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      // A finished download leaves its resume state in the title folder.
      final engine = native.loopbackEngine();
      late String hash;
      try {
        hash = await engine.add(
          TorrentSource.metadata(metadata),
          owner: 'download',
          directory: show.path,
          storage: TorrentStorage.kept,
        );
        await engine.metadata(hash);
        await engine.rename(hash, {0: 'Season 01/Show S01E01.mp4'});
        expect(await engine.verify(hash), [bytes.length]);
      } finally {
        await engine.close();
      }
      final entry = LibraryEntry(
        item: PlaybackItem(
          title: fakeTitle(3),
          series: fakeTitle(2, series: true),
          season: 1,
          episode: 1,
        ),
        downloadId: 'cleared',
        release: TorrentRelease(
          source: TorrentSourceId.pirateBay,
          name: 'release',
          infoHash: hash,
          magnet: magnetFor(hash, 'release'),
          seeders: 1,
          sizeBytes: 256 * 1024,
        ),
        fileIndex: 0,
        path: file.path,
        addedAt: DateTime(2026),
      );
      final queue = DownloadQueue(
        FakeTorrents(),
        DownloadRepository(JsonFileStore(File('${root.path}/downloads.json'))),
      );
      final container = ProviderContainer(
        overrides: [
          ...libraryOverrides([entry]),
          internetProbeProvider.overrideWithValue(() async => false),
          downloadQueueProvider.overrideWithValue(queue),
        ],
      );
      try {
        final integrity = container.read(libraryIntegrityProvider);
        // Offline, so these can only come from the resume state.
        expect(await integrity.metadata(entry), isNotNull);
        final valid = await integrity.check(entry);
        expect(valid.state, IntegrityState.valid, reason: valid.message);
        final library = container.read(libraryProvider);
        expect(library.single.verifiedAt, isNotNull);
        // No stray resume state beside the episode.
        expect(
          await File('${file.parent.path}/.$hash.resume').exists(),
          isFalse,
        );
        final disk = await file.open(mode: FileMode.writeOnlyAppend);
        await disk.setPosition(65536);
        await disk.writeFrom(Uint8List(65536));
        await disk.close();
        final damaged = await integrity.check(library.single);
        expect(damaged.state, IntegrityState.damaged, reason: damaged.message);
      } finally {
        container.dispose();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
