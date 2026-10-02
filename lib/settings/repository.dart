import 'package:logging/logging.dart';

import '../shared/persistence/json_file_store.dart';
import 'models.dart';

class SettingsRepository {
  SettingsRepository(this.store);
  final JsonFileStore store;
  Future<AppSettings> load() async {
    final json = await store.read();
    if (json != null) return AppSettings.fromJson(json);
    Logger('sentorr.settings').info('No saved settings; writing defaults');
    const defaults = AppSettings();
    await save(defaults);
    return defaults;
  }

  Future<void> save(AppSettings settings) => store.write(settings.toJson());
}
