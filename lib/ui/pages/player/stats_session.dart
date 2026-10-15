import 'dart:io';
import 'dart:ui';

import '../../../player/diagnostics.dart';
import '../../../settings/models.dart';
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
          : await _freeBytes(paths.rootDirectory.path),
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

/// Free space on [path]'s volume, where desktops can tell; a full disk
/// stalls a torrent without any network symptom.
Future<int?> _freeBytes(String path) async {
  if (!Platform.isMacOS && !Platform.isLinux) return null;
  try {
    final result = await Process.run('df', ['-k', path]);
    final row = (result.stdout as String).trim().split('\n').last;
    final available = int.tryParse(row.split(RegExp(r'\s+'))[3]);
    return available == null ? null : available * 1024;
  } catch (_) {
    return null;
  }
}
