import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  AppPaths._(this.rootDirectory, this.defaultDownloadsDirectory);
  final Directory rootDirectory;

  /// Where downloads go unless the viewer chose a folder: a Sentorr folder
  /// in the system's downloads, or the app's own when there is none.
  final Directory defaultDownloadsDirectory;
  Directory directory(String name) =>
      Directory(path.join(rootDirectory.path, name));
  File get settingsFile =>
      File(path.join(rootDirectory.path, 'settings', 'settings.json'));
  File get windowStateFile =>
      File(path.join(rootDirectory.path, 'state', 'window.json'));
  File get watchHistoryFile =>
      File(path.join(rootDirectory.path, 'state', 'watch_history.json'));
  File get followedSeriesFile =>
      File(path.join(rootDirectory.path, 'state', 'followed_series.json'));
  File get downloadsFile =>
      File(path.join(rootDirectory.path, 'state', 'downloads.json'));
  File get libraryFile =>
      File(path.join(rootDirectory.path, 'state', 'library.json'));
  Directory get networkCacheDirectory => directory('cache/http');
  Directory get imageCacheDirectory => directory('cache/images');

  /// Torrent streaming sessions keep their pieces in children of this,
  /// unless the viewer chose another torrent folder.
  Directory get streamCacheDirectory => directory('cache/streams');

  /// Which kept torrents were watched when, wherever they are saved.
  File get torrentCacheIndexFile =>
      File(path.join(rootDirectory.path, 'cache', 'metadata', 'torrents.json'));
  File get imageCacheMetadataFile =>
      File(path.join(rootDirectory.path, 'cache', 'metadata', 'images.json'));
  File get sourceDirectoryFile =>
      File(path.join(rootDirectory.path, 'state', 'source-directory.json'));
  File get sourceDirectoryFetchStateFile => File(
    path.join(rootDirectory.path, 'state', 'source-directory-fetch.json'),
  );
  Directory get updatesDirectory => directory('updates');
  File get updateManifestFile =>
      File(path.join(updatesDirectory.path, 'manifest.json'));
  File get updateStateFile =>
      File(path.join(updatesDirectory.path, 'state.json'));
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
    final system = rootDirectory == null ? await _systemDownloads() : null;
    final paths = AppPaths._(
      root,
      Directory(
        system == null
            ? path.join(root.path, 'downloads')
            : path.join(system.path, 'Sentorr'),
      ),
    );
    for (final name in [
      'settings',
      'state',
      'cache/http',
      'cache/images',
      'cache/metadata',
      'cache/streams',
      'logs',
      'updates',
    ]) {
      await paths.directory(name).create(recursive: true);
    }
    return paths;
  }

  static Future<Directory?> _systemDownloads() async {
    try {
      final folder = await getDownloadsDirectory();
      // The macOS sandbox hands out a link to the real folder; name that.
      if (folder == null || !await folder.exists()) return folder;
      return Directory(await folder.resolveSymbolicLinks());
    } catch (_) {
      return null;
    }
  }
}
