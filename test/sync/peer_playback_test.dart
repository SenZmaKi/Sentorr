import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/stream/offline_source.dart';
import 'package:sentorr/sync/peer_playback.dart';
import 'package:sentorr/sync/peers.dart';
import 'package:sentorr/sync/service.dart';

import '../support/fake_imdb.dart';
import '../support/fake_torrents.dart';
import 'harness.dart';

final _lookup = Provider<PeerLookup>(
  (ref) =>
      (item, excluded) => verifiedPeerSource(ref, item, excluded),
);

void main() {
  test('playback recovers offline peer, verifies files and excludes failed sources', () async {
    final root = await Directory.systemTemp.createTemp('peer-playback-');
    final file = await File('${root.path}/movie.mkv').writeAsBytes([1, 2, 3]);
    final item = PlaybackItem(title: fakeTitle(1));
    final entry = LibraryEntry(
      item: item,
      downloadId: 'done',
      release: fakeRelease(1),
      fileIndex: 0,
      path: file.path,
      addedAt: DateTime(2026),
    );
    final host = await syncDevice('Host', library: [entry]);
    final viewer = await syncDevice('Viewer');
    try {
      await pair(host, viewer);
      await viewer.read(peersProvider.notifier).syncWith(idOf(host));
      viewer.read(peersProvider.notifier).lost(idOf(host));
      expect(viewer.read(peersProvider)[idOf(host)]!.online, isFalse);
      final source = await viewer.read(_lookup)(item, {});
      expect(source, isA<PeerFile>());
      expect(viewer.read(peersProvider)[idOf(host)]!.online, isTrue);
      expect(await viewer.read(_lookup)(item, {source!.url}), isNull);
      await file.delete();
      expect(await viewer.read(_lookup)(item, {}), isNull);
    } finally {
      await host.read(syncServiceProvider).close();
      await viewer.read(syncServiceProvider).close();
      await root.delete(recursive: true);
    }
  });
}
