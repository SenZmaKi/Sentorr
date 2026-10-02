import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../imdb/repository.dart';
import '../settings/models.dart';
import '../settings/repository.dart';
import '../shared/net/net.dart';
import '../shared/persistence/app_paths.dart';
import '../shared/persistence/app_image_cache.dart';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

final appPathsProvider = Provider<AppPaths>(
  (ref) => throw StateError('Bootstrap must override appPathsProvider'),
);
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) =>
      throw StateError('Bootstrap must override settingsRepositoryProvider'),
);
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => throw StateError('Bootstrap must override initialSettingsProvider'),
);
final networkClientProvider = Provider<NetworkClient>(
  (ref) => throw StateError('Bootstrap must override networkClientProvider'),
);
final imageCacheProvider = Provider<CacheManager>(
  (ref) => AppImageCache.manager,
);
final imdbRepositoryProvider = Provider<ImdbRepository>(
  (ref) => ImdbRepository(ref.watch(networkClientProvider).dio),
);
