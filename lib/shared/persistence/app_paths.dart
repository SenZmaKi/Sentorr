import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  AppPaths._(this.rootDirectory);
  final Directory rootDirectory;
  Directory directory(String name) =>
      Directory(path.join(rootDirectory.path, name));
  File get settingsFile =>
      File(path.join(rootDirectory.path, 'settings', 'settings.json'));
  File get windowStateFile =>
      File(path.join(rootDirectory.path, 'state', 'window.json'));
  Directory get networkCacheDirectory => directory('cache/http');
  Directory get imageCacheDirectory => directory('cache/images');

  /// Torrent streaming sessions keep their pieces in children of this.
  Directory get streamCacheDirectory => directory('cache/streams');
  File get imageCacheMetadataFile =>
      File(path.join(rootDirectory.path, 'cache', 'metadata', 'images.json'));
  Directory get logsDirectory => directory('logs');

  static Future<AppPaths> initialize({Directory? rootDirectory}) async {
    final root =
        rootDirectory ??
        Directory(
          path.join(
            (await getApplicationSupportDirectory()).path,
            'SentorrData',
          ),
        );
    final paths = AppPaths._(root);
    for (final name in [
      'settings',
      'state',
      'cache/http',
      'cache/images',
      'cache/metadata',
      'cache/streams',
      'logs',
    ]) {
      await paths.directory(name).create(recursive: true);
    }
    return paths;
  }
}
