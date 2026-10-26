import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/sync/file_version.dart';
import 'package:sentorr/sync/client.dart';
import 'package:sentorr/sync/continuity/host.dart';
import 'package:sentorr/sync/continuity/notifier.dart';
import 'package:sentorr/sync/continuity/receiver.dart';
import 'package:sentorr/sync/continuity/session.dart';
import 'package:sentorr/sync/payload.dart';
import 'package:sentorr/sync/peers.dart';
import 'package:sentorr/sync/server.dart';
import 'package:sentorr/sync/service.dart';
import 'package:sentorr/sync/devices.dart';
import 'package:sentorr/sync/models.dart';

import '../support/fake_imdb.dart';
import '../support/fake_torrents.dart';
import 'harness.dart';

ContinuitySession session({String id = 'session-1', bool buffered = false}) =>
    ContinuitySession(
      id: id,
      media: PeerMedia(
        item: PlaybackItem(title: fakeTitle(1)),
        size: 100,
        name: 'movie.mp4',
        release: fakeRelease(1),
        fileIndex: 2,
        version: buffered ? null : 'file-v1',
        bufferedBytes: buffered ? 42 : null,
      ),
      position: const Duration(seconds: 30),
      duration: const Duration(minutes: 5),
      playing: true,
    );

// Drop one successful acknowledgement after the real server has paused.
class LostAcknowledgementClient extends PeerClient {
  LostAcknowledgementClient(super.identity, {required super.port});
  bool lost = false;
  @override
  Future<Map<String, dynamic>> call(
    DeviceAddress to,
    String fingerprint,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final result = await super.call(
      to,
      fingerprint,
      path,
      body: body,
      headers: headers,
      timeout: timeout,
    );
    if (path.endsWith('/take') && !lost) {
      lost = true;
      throw const PeerException('Lost acknowledgement');
    }
    return result;
  }
}

void main() {
  for (final buffered in [false, true]) {
    test('presence round trips exact source (buffered=$buffered)', () {
      final original = session(buffered: buffered);
      final decoded = ContinuitySession.decode(original.toJson())!;
      expect(decoded.media.release.infoHash, original.media.release.infoHash);
      expect(decoded.media.fileIndex, 2);
      expect(decoded.buffered, buffered);
      expect(decoded.media.version, original.media.version);
      expect(decoded.position, original.position);
    });
  }

  test('rejects malformed positions rather than seeking with invalid data', () {
    for (final position in [-1, 1.5, '30', 300001]) {
      expect(
        () => ContinuitySession.decode({
          ...session().toJson(),
          'position': position,
        }),
        throwsFormatException,
      );
    }
  });

  test(
    'concurrent duplicate handoffs pause once; another receiver cannot claim',
    () async {
      var pauses = 0;
      final paused = Completer<Duration>();
      final host = ContinuityHost()
        ..snapshot = () async {
          return session();
        }
        ..pause = (_, authorized) {
          pauses++;
          return paused.future;
        };
      final body = {'session': 'session-1', 'handoff': 'take-1'};
      final first = host.take('phone', 'Phone', body);
      final retry = host.take('phone', 'Phone', body);
      await Future<void>.delayed(Duration.zero);
      expect(pauses, 1);
      await expectLater(
        host.take('other', 'Other', body),
        throwsA(isA<SyncRefusal>()),
      );
      paused.complete(const Duration(seconds: 31));
      expect(await first, {'position': 31000});
      expect(await retry, {'position': 31000});
      expect(await host.take('phone', 'Phone', body), {'position': 31000});
      expect(pauses, 1);
    },
  );

  test(
    'old session cannot pause a replacement; a new session can transfer',
    () async {
      var current = session();
      var pauses = 0;
      final host = ContinuityHost()
        ..snapshot = () async {
          return current;
        }
        ..pause = (_, authorized) async {
          pauses++;
          return current.position;
        };
      await host.take('phone', 'Phone', {
        'session': current.id,
        'handoff': 'a',
      });
      current = session(id: 'session-2');
      await expectLater(
        host.take('phone', 'Phone', {'session': 'session-1', 'handoff': 'b'}),
        throwsA(isA<SyncRefusal>()),
      );
      expect(pauses, 1);
      await host.take('phone', 'Phone', {
        'session': current.id,
        'handoff': 'b',
      });
      expect(pauses, 2);
    },
  );

  group('two paired localhost devices', () {
    late ProviderContainer host, phone;
    late ContinuityHost hosting;
    late int pauses;
    setUp(() async {
      host = await syncDevice('MacBook');
      phone = await syncDevice('Phone');
      final hostService = host.read(syncServiceProvider);
      final phoneService = phone.read(syncServiceProvider);
      addTearDown(() async {
        await hostService.close();
        await phoneService.close();
      });
      await pair(host, phone);
      pauses = 0;
      hosting = host.read(continuityHostProvider)
        ..snapshot = () async {
          return session();
        }
        ..pause = (_, authorized) async {
          pauses++;
          return const Duration(seconds: 34);
        };
    });

    Future<void> receive({
      Future<void> Function(ContinuitySession)? prepare,
      Future<void> Function(Duration)? start,
      bool Function()? current,
    }) => receiveContinuity(
      client: phone.read(syncServiceProvider).client,
      route: phone.read(peersProvider.notifier).route(idOf(host))!,
      sessionId: 'session-1',
      handoffId: 'transaction-1',
      current: current ?? () => true,
      prepare: prepare ?? (_) async {},
      start: start ?? (_) async {},
    );

    test(
      'source keeps playing through preparation and supplies final position',
      () async {
        final ready = Completer<void>();
        final preparing = Completer<void>();
        Duration? started;
        final operation = receive(
          prepare: (s) async {
            expect(s.position.inSeconds, 30);
            preparing.complete();
            await ready.future;
          },
          start: (position) async {
            started = position;
          },
        );
        await preparing.future;
        expect(pauses, 0);
        ready.complete();
        await operation;
        expect(pauses, 1);
        expect(started, const Duration(seconds: 34));
      },
    );

    test(
      'lost acknowledgement retries the same transaction and pauses once',
      () async {
        final client = LostAcknowledgementClient(
          phone.read(devicesProvider).identity,
          port: () => phone.read(syncServiceProvider).server.port,
        );
        addTearDown(client.close);
        final route = phone.read(peersProvider.notifier).route(idOf(host))!;
        Duration? started;
        await receiveContinuity(
          client: client,
          route: route,
          sessionId: 'session-1',
          handoffId: 'lost-ack',
          current: () => true,
          prepare: (_) async {},
          start: (p) async {
            started = p;
          },
        );
        expect(client.lost, true);
        expect(pauses, 1);
        expect(started, const Duration(seconds: 34));
        expect((await hosting.presence())['session'], isNull);
      },
    );

    test('failed preparation never pauses source', () async {
      await expectLater(
        receive(prepare: (_) async => throw StateError('decode failed')),
        throwsStateError,
      );
      expect(pauses, 0);
    });

    test('closing target during preparation never pauses source', () async {
      var active = true;
      await expectLater(
        receive(
          current: () => active,
          prepare: (_) async {
            active = false;
          },
        ),
        throwsA(isA<PeerException>()),
      );
      expect(pauses, 0);
    });

    test(
      'source switching episodes during preparation refuses stale take',
      () async {
        await expectLater(
          receive(
            prepare: (_) async {
              hosting.snapshot = () async => session(id: 'session-2');
            },
          ),
          throwsA(isA<PeerException>().having((e) => e.status, 'status', 409)),
        );
        expect(pauses, 0);
      },
    );

    test('unpairing during preparation revokes take', () async {
      await expectLater(
        receive(
          prepare: (_) async {
            await host.read(syncServiceProvider).unpair(idOf(phone));
          },
        ),
        throwsA(isA<PeerException>()),
      );
      expect(pauses, 0);
    });

    test(
      'unpairing during an in-flight take snapshot prevents pause',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        hosting.snapshot = () async {
          entered.complete();
          await release.future;
          return session();
        };
        final route = phone.read(peersProvider.notifier).route(idOf(host))!;
        final take = phone
            .read(syncServiceProvider)
            .client
            .call(
              route.address,
              route.fingerprint,
              '/v1/continuity/take',
              body: {'session': 'session-1', 'handoff': 'race'},
            );
        final refused = expectLater(
          take,
          throwsA(isA<PeerException>().having((e) => e.status, 'status', 403)),
        );
        await entered.future;
        await host.read(syncServiceProvider).unpair(idOf(phone));
        release.complete();
        await refused;
        expect(pauses, 0);
      },
    );

    test(
      'sidecar transfer uses paired transport and refuses after unpair',
      () async {
        hosting.caption = (id) async =>
            id == 'session-1' ? '1\n00:00:00,000 --> 00:00:01,000\nHi' : null;
        final route = phone.read(peersProvider.notifier).route(idOf(host))!;
        final client = phone.read(syncServiceProvider).client;
        final caption = await client.call(
          route.address,
          route.fingerprint,
          '/v1/continuity/caption',
          body: {'session': 'session-1'},
        );
        expect(caption['data'], contains('Hi'));
        await expectLater(
          client.call(
            route.address,
            route.fingerprint,
            '/v1/continuity/caption',
            body: {'session': 'old'},
          ),
          throwsA(isA<PeerException>().having((e) => e.status, 'status', 404)),
        );
        await host.read(syncServiceProvider).unpair(idOf(phone));
        await expectLater(
          client.call(
            route.address,
            route.fingerprint,
            '/v1/continuity/caption',
            body: {'session': 'session-1'},
          ),
          throwsA(isA<PeerException>()),
        );
      },
    );

    test(
      'presence appears, dismisses per session, and clears when offline',
      () async {
        final subscription = phone.listen(continuityOffersProvider, (_, _) {});
        addTearDown(subscription.close);
        final notifier = phone.read(continuityOffersProvider.notifier);
        await until(() => phone.read(continuityOffersProvider).isNotEmpty);
        final offer = phone.read(continuityOffersProvider).single;
        expect(offer.deviceName, 'MacBook');
        notifier.dismiss(offer);
        await notifier.refresh();
        expect(phone.read(continuityOffersProvider), isEmpty);
        hosting.snapshot = () async => session(id: 'new');
        await notifier.refresh();
        expect(phone.read(continuityOffersProvider).single.session.id, 'new');
        await host.read(syncServiceProvider).close();
        await notifier.refresh();
        expect(phone.read(continuityOffersProvider), isEmpty);
      },
    );

    test('streaming proxy pins completed file version', () async {
      final http = HttpClient();
      addTearDown(() => http.close(force: true));
      final root = await Directory.systemTemp.createTemp('continuity-file-');
      addTearDown(() => root.delete(recursive: true));
      final file = await File('${root.path}/movie.mp4')
          .writeAsBytes([1, 2, 3, 4]);
      await host
          .read(libraryProvider.notifier)
          .add(
            LibraryEntry(
              item: session().media.item,
              downloadId: 'complete',
              release: fakeRelease(1),
              fileIndex: 2,
              path: file.path,
              addedAt: DateTime.now(),
            ),
          );
      final proxy = phone.read(syncServiceProvider).proxy;
      final valid = proxy.url(
        idOf(host),
        'tt1',
        fileVersion: fileVersion(file),
      )!;
      final request = await http.getUrl(valid);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=1-2');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.partialContent);
      expect(
        await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk)),
        [2, 3],
      );
      final stale = proxy.url(idOf(host), 'tt1', fileVersion: 'old')!;
      final refused = await (await http.getUrl(stale)).close();
      expect(refused.statusCode, HttpStatus.preconditionFailed);
      await refused.drain<void>();
    });
  });
}
