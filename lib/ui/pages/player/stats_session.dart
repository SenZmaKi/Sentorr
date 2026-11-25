import 'dart:io';
import 'dart:ui';

import '../../../player/diagnostics.dart';
import '../../../settings/models.dart';
import '../../../shared/disk_space.dart';
import '../../../shared/persistence/app_paths.dart';

/// What a recording ran under: device, player configuration and the
/// settings that shape streaming. Recordings get shared, so proxy
/// credentials and personal folder paths stay out.
Future<Map<String, Object?>> describeStatsSession({
  required AppSettings settings,
  required AppPaths? paths,
  required PlaybackDiagnostics diagnostics,
}) async {
  final streaming = {...settings.streaming.toJson()};
  final torrentDirectory = streaming.remove('torrentDirectory');
  final network = {...settings.network.toJson()};
  network['proxy'] = settings.network.proxy.kind.name;
  return {
    'device': {
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'processors': Platform.numberOfProcessors,
      'dart': Platform.version.split(' ').first,
      'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
      'freeDiskBytes': paths == null
          ? null
          : await freeBytes(paths.rootDirectory.path),
    },
    'player': await diagnostics.readConfig(),
    'settings': {
      'streaming': {
        ...streaming,
        'customTorrentDirectory':
            torrentDirectory is String && torrentDirectory.isNotEmpty,
      },
      'network': network,
      'cacheMaxBytes': settings.cache.maxBytes,
      'torrents': settings.torrents.toJson(),
    },
  };
}
