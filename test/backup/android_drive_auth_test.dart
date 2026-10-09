import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/backup/drive/android_drive_auth.dart';
import 'package:sentorr/backup/watch_backup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sentorr/drive_auth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late AndroidDriveAuth auth;
  late Future<Object?> Function(MethodCall) handler;

  setUp(() {
    calls = [];
    auth = AndroidDriveAuth(dio: Dio());
    handler = (call) async => switch (call.method) {
      'restore' => true,
      'authorize' => 'native-token',
      'forget' => null,
      _ => throw StateError('Unexpected native operation'),
    };
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('connect obtains native access and permits consent', () async {
    await auth.connect();
    expect(auth.connected, isTrue);
    expect(calls.single.method, 'authorize');
    expect(calls.single.arguments, {'interactive': true});
  });

  test('restored sign-in renews through SDK without permission UI', () async {
    expect(await auth.restore(), isTrue);
    expect(await auth.accessToken(), 'native-token');
    expect(calls.last.arguments, {'interactive': false});
  });

  test('parallel requests share the native authorization operation', () async {
    await auth.restore();
    final token = Completer<String>();
    handler = (_) => token.future;
    final first = auth.accessToken();
    final second = auth.accessToken();
    token.complete('renewed-token');
    expect(await Future.wait([first, second]), [
      'renewed-token',
      'renewed-token',
    ]);
    expect(calls.where((call) => call.method == 'authorize'), hasLength(1));
  });

  test('401 refresh invalidates the previously returned SDK token', () async {
    await auth.connect();
    await auth.refresh();
    expect(calls.last.arguments, {
      'interactive': false,
      'invalidateToken': 'native-token',
    });
  });

  test('permission removal requires explicit reconnect', () async {
    await auth.restore();
    handler = (_) async => throw PlatformException(
      code: 'reauthorize_required',
      message: 'Connect again.',
    );
    await expectLater(auth.accessToken(), throwsA(isA<BackupException>()));
    expect(auth.connected, isFalse);
  });

  test('cancelled consent stays disconnected and can be retried', () async {
    handler = (_) async => throw PlatformException(code: 'cancelled');
    await expectLater(auth.connect(), throwsA(isA<BackupException>()));
    expect(auth.connected, isFalse);
    handler = (_) async => 'retry-token';
    await auth.connect();
    expect(auth.connected, isTrue);
  });

  test('absent native access is not treated as connected', () async {
    handler = (_) async => '';
    await expectLater(auth.connect(), throwsA(isA<BackupException>()));
    expect(auth.connected, isFalse);
  });

  test(
    'disconnect after restart obtains access silently and revokes it',
    () async {
      await auth.restore();
      RequestOptions? revoke;
      auth.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            revoke = request;
            handler.resolve(Response(requestOptions: request, statusCode: 200));
          },
        ),
      );
      await auth.disconnect();
      expect(calls.map((call) => call.method), [
        'restore',
        'authorize',
        'forget',
      ]);
      expect(calls[1].arguments, {'interactive': false});
      expect(revoke?.path, 'https://oauth2.googleapis.com/revoke');
      expect(revoke?.data, {'token': 'native-token'});
      expect(auth.connected, isFalse);
    },
  );

  test('disconnect during consent cannot restore connection later', () async {
    final token = Completer<String>();
    handler = (call) async => call.method == 'authorize' ? token.future : null;
    final connect = auth.connect();
    final failed = expectLater(connect, throwsA(isA<BackupException>()));
    final disconnect = auth.disconnect();
    token.complete('late-token');
    await failed;
    await disconnect;
    expect(auth.connected, isFalse);
    expect(calls.last.method, 'forget');
  });
}
