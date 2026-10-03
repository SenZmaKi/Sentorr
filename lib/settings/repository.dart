import 'package:logging/logging.dart';

import '../shared/persistence/credential_store.dart';
import '../shared/persistence/json_file_store.dart';
import 'models.dart';

class SettingsRepository {
  /// Without [credentials], as in debug builds and tests, proxy credentials
  /// stay in the settings file.
  SettingsRepository(this.store, {this.credentials});
  final JsonFileStore store;
  final CredentialStore? credentials;
  ProxyCredentials? _savedCredentials;

  Future<AppSettings> load() async {
    final json = await store.read();
    if (json == null) {
      Logger('sentorr.settings').info('No saved settings; writing defaults');
      const defaults = AppSettings();
      await save(defaults);
      return defaults;
    }
    final settings = AppSettings.fromJson(json);
    final saved = await credentials?.readProxy();
    if (saved == null) return settings;
    _savedCredentials = saved;
    final network = settings.network;
    return settings.copyWith(
      network: network.copyWith(
        proxy: network.proxy.copyWith(
          username: saved.username,
          password: saved.password,
        ),
      ),
    );
  }

  Future<void> save(AppSettings settings) async {
    final credentials = this.credentials;
    if (credentials == null) return store.write(settings.toJson());
    final network = settings.network;
    final proxy = network.proxy;
    final login = (username: proxy.username, password: proxy.password);
    if (login != _savedCredentials) {
      await credentials.writeProxy(login);
      _savedCredentials = login;
    }
    final withoutLogin = proxy.copyWith(username: '', password: '');
    return store.write(
      settings
          .copyWith(network: network.copyWith(proxy: withoutLogin))
          .toJson(),
    );
  }
}
