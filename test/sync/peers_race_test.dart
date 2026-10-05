import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/backup/watch_backup.dart';
import 'package:sentorr/following/snapshot.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/sync/client.dart';
import 'package:sentorr/sync/identity.dart';
import 'package:sentorr/sync/models.dart';
import 'package:sentorr/sync/payload.dart';
import 'package:sentorr/sync/peers.dart';
import 'package:sentorr/sync/service.dart';
import 'package:sentorr/sync/shared_library.dart';
import 'package:sentorr/watching/models.dart';
import 'package:sentorr/watching/notifier.dart';
import 'package:sentorr/following/notifier.dart';

import '../support/fake_following.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_sync.dart';

final _shapeProvider = NotifierProvider<_Shape, String>(_Shape.new);

class _Shape extends Notifier<String> {
  @override
  String build() => '';
  void change(String value) => state = value;
}

class _BlockingHistory extends MemoryWatchHistory {
  final entered = Completer<void>(), release = Completer<void>();
  bool enabled = false;
  @override
  Future<void> save(List<WatchEntry> entries) async {
    if (enabled) {
      entered.complete();
      await release.future;
    }
    await super.save(entries);
  }
}

class _Client extends PeerClient {
  _Client() : super(DeviceIdentity.generate('Local'), port: () => 1);
  final calls = <(String, Completer<Map<String, dynamic>>)>[];

  @override
  Future<Map<String, dynamic>> call(
    DeviceAddress to,
    String fingerprint,
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 20),
  }) {
    final result = Completer<Map<String, dynamic>>();
    calls.add((path, result));
    return result.future;
  }
}

class _Service extends SyncService {
  _Service(super.ref, this.transport);
  final _Client transport;
  @override
  PeerClient get client => transport;
}

Map<String, dynamic> _payload({int? item, double progress = .8}) => {
  ...SyncPayload(
    watch: WatchSnapshot([
      if (item != null)
        WatchEntry(
          title: fakeTitle(item),
          position: const Duration(minutes: 10),
          duration: const Duration(minutes: 90),
          updatedAt: DateTime.now(),
        ),
    ], {}),
    following: const FollowedSnapshot([], {}),
  ).toJson(),
  'library': PeerLibrary(
    downloads: [
      PeerDownload(
        item: PlaybackItem(title: fakeTitle(9)),
        transfer: PeerTransfer.downloading,
        progress: progress,
      ),
    ],
  ).toJson(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late PairedDevice peer;
  late ProviderContainer container;
  late PeersNotifier peers;
  late _BlockingHistory history;
  setUp(() {
    client = _Client();
    history = _BlockingHistory();
    final identity = DeviceIdentity.generate('Peer');
    peer = PairedDevice(
      id: identity.id,
      name: 'Peer',
      certificatePem: identity.certificatePem,
      pairedAt: DateTime.now(),
      address: (host: '127.0.0.1', port: 1),
    );
    container = ProviderContainer(
      overrides: [
        ...syncOverrides(devices: [peer]),
        ...watchHistoryOverrides([], history),
        ...followedSeriesOverrides(),
        ...libraryOverrides(),
        sharedLibraryShapeProvider.overrideWith(
          (ref) => ref.watch(_shapeProvider),
        ),
        syncServiceProvider.overrideWith((ref) => _Service(ref, client)),
      ],
    );
    peers = container.read(peersProvider.notifier);
  });
  tearDown(() {
    container.dispose();
    client.close();
  });

  test('unpair ignores a delayed outgoing response', () async {
    final pending = peers.syncWith(peer.id);
    expect(client.calls, hasLength(1));
    await container.read(syncServiceProvider).unpair(peer.id);
    client.calls.single.$2.complete(_payload(item: 1));
    await pending;
    expect(container.read(watchHistoryProvider), isEmpty);
    expect(container.read(peersProvider), isEmpty);
  });

  test('unpair rejects a previously authenticated incoming request', () async {
    await container.read(syncServiceProvider).unpair(peer.id);
    await expectLater(peers.answer(peer, _payload(item: 1)), throwsStateError);
    expect(container.read(watchHistoryProvider), isEmpty);
  });

  test(
    'unpair during an incoming merge prevents the remaining state and status',
    () async {
      history.enabled = true;
      final incoming = _payload(item: 1);
      incoming['following'] = FollowedSnapshot([
        following(fakeTitle(2, series: true), episode: 1),
      ], {}).toJson();
      final answer = peers.answer(peer, incoming);
      await history.entered.future;
      await container.read(syncServiceProvider).unpair(peer.id);
      history.release.complete();
      await expectLater(answer, throwsStateError);
      expect(container.read(followedSeriesProvider), isEmpty);
      expect(container.read(peersProvider), isEmpty);
    },
  );

  test(
    'polls are serialized and a completed sync invalidates the old poll',
    () async {
      final poll = peers.refreshLibrary(peer.id);
      await peers.refreshLibrary(peer.id);
      expect(client.calls, hasLength(1));
      final sync = peers.syncWith(peer.id);
      client.calls[1].$2.complete(_payload(progress: .9));
      await sync;
      client.calls[0].$2.complete(
        PeerLibrary.fromJson(_payload(progress: .2)['library']).toJson(),
      );
      await poll;
      expect(
        container.read(peersProvider)[peer.id]!.downloads.single.progress,
        .9,
      );
    },
  );

  test(
    'a stale poll failure cannot mark a freshly synced peer offline',
    () async {
      final poll = peers.refreshLibrary(peer.id);
      final sync = peers.syncWith(peer.id);
      client.calls[1].$2.complete(_payload());
      await sync;
      client.calls[0].$2.completeError(const PeerException('old timeout'));
      await poll;
      expect(container.read(peersProvider)[peer.id]!.online, true);
    },
  );

  test('incoming sync supersedes an older outgoing library', () async {
    final outgoing = peers.syncWith(peer.id);
    await peers.answer(peer, _payload(progress: .9));
    client.calls.single.$2.complete(_payload(progress: .2));
    await outgoing;
    expect(
      container.read(peersProvider)[peer.id]!.downloads.single.progress,
      .9,
    );
  });

  testWidgets('watch bursts cannot postpone the original ten-second deadline', (
    tester,
  ) async {
    await container
        .read(watchHistoryProvider.notifier)
        .record(
          PlaybackItem(title: fakeTitle(1)),
          position: const Duration(minutes: 10),
          duration: const Duration(minutes: 90),
        );
    await tester.pump(const Duration(seconds: 5));
    await container
        .read(watchHistoryProvider.notifier)
        .record(
          PlaybackItem(title: fakeTitle(1)),
          position: const Duration(minutes: 20),
          duration: const Duration(minutes: 90),
        );
    await tester.pump(const Duration(seconds: 5));
    expect(client.calls, hasLength(1));
    client.calls.single.$2.complete(_payload());
    await tester.pump();
    container.dispose();
  });
  testWidgets('watch changes cannot postpone a two-second library deadline', (
    tester,
  ) async {
    container.read(_shapeProvider.notifier).change('transfer');
    expect(container.read(sharedLibraryShapeProvider), 'transfer');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await container
        .read(watchHistoryProvider.notifier)
        .record(
          PlaybackItem(title: fakeTitle(1)),
          position: const Duration(minutes: 10),
          duration: const Duration(minutes: 90),
        );
    await tester.pump(const Duration(seconds: 1));
    expect(client.calls, hasLength(1));
    client.calls.single.$2.complete(_payload());
    await tester.pump();
    container.dispose();
  });
}
