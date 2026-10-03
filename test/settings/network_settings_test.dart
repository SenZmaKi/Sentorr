import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/settings/repository.dart';
import 'package:sentorr/shared/persistence/credential_store.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:torrent_stream/torrent_stream.dart';

class _MemoryCredentials extends CredentialStore {
  ProxyCredentials? saved;
  int writes = 0;

  @override
  Future<ProxyCredentials?> readProxy() async => saved;

  @override
  Future<void> writeProxy(ProxyCredentials credentials) async {
    writes++;
    saved = credentials;
  }
}

const _proxied = AppSettings(
  network: NetworkSettings(
    networkInterface: 'wg0',
    proxy: ProxySettings(
      kind: TorrentProxyKind.socks5,
      host: 'proxy.example',
      port: 9050,
      username: 'user',
      password: 'secret',
    ),
  ),
);

void main() {
  late Directory dir;
  late JsonFileStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sentorr_settings');
    store = JsonFileStore(File('${dir.path}/settings.json'));
  });
  tearDown(() => dir.delete(recursive: true));

  test('the proxy and interface survive a round trip', () {
    final n = AppSettings.fromJson(_proxied.toJson()).network;
    expect(n.networkInterface, 'wg0');
    expect(n.proxy.kind, TorrentProxyKind.socks5);
    expect(n.proxy.host, 'proxy.example');
    expect(n.proxy.port, 9050);
    expect(n.proxy.password, 'secret');
  });

  test('older and malformed settings fall back to a direct route', () {
    final n = NetworkSettings.fromJson({
      'proxy': {'kind': 'tor', 'port': 70000},
      'networkInterface': '  ',
    });
    expect(n.proxy.enabled, isFalse);
    expect(n.proxy.port, 1080);
    expect(n.networkInterface, isNull);
    expect(const NetworkSettings().proxy.enabled, isFalse);
  });

  test('any interface clears the binding', () {
    final n = _proxied.network.copyWith(anyInterface: true);
    expect(n.networkInterface, isNull);
  });

  test('credentials go to the keychain, not the settings file', () async {
    final credentials = _MemoryCredentials();
    final repository = SettingsRepository(store, credentials: credentials);
    await repository.save(_proxied);
    await repository.save(_proxied);

    final file = await store.read();
    final proxy = file!['network']['proxy'] as Map;
    expect(proxy['username'], '');
    expect(proxy['password'], '');
    expect(proxy['host'], 'proxy.example');
    expect(credentials.saved, (username: 'user', password: 'secret'));
    expect(credentials.writes, 1);

    final loaded = await SettingsRepository(
      store,
      credentials: credentials,
    ).load();
    expect(loaded.network.proxy.username, 'user');
    expect(loaded.network.proxy.password, 'secret');
  });

  test('credentials left in the file move to the keychain', () async {
    await SettingsRepository(store).save(_proxied);
    final credentials = _MemoryCredentials();
    final repository = SettingsRepository(store, credentials: credentials);
    final loaded = await repository.load();
    expect(loaded.network.proxy.password, 'secret');
    await repository.save(loaded);
    expect(credentials.saved, (username: 'user', password: 'secret'));
    final file = await store.read();
    expect((file!['network']['proxy'] as Map)['password'], '');
  });
}
