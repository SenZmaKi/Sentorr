import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../../../player/playback_events.dart';
import '../../../player/stats_recording.dart';
import '../../../shared/persistence/app_paths.dart';

/// Where a finished stats recording goes.
abstract final class StatsExport {
  /// [recording] with the playback events from its pre-roll to its end.
  static Future<String> encode(
    StatsRecording recording,
    PlaybackEvents events,
  ) async {
    String? version;
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    return recording.toJson(
      extra: {'app': version},
      events: events.between(
        recording.startedAt.subtract(recording.preRoll),
        recording.stoppedAt,
      ),
    );
  }

  static Future<void> copy(String json) =>
      Clipboard.setData(ClipboardData(text: json));

  /// False when the viewer cancels the save dialog.
  static Future<bool> save(String json, String title, DateTime at) async {
    final bytes = utf8.encode(json);
    final safeTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save stats recording',
      fileName: '$safeTitle-stats-${at.millisecondsSinceEpoch}.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
    if (path == null) return false;
    // Mobile pickers write the bytes; desktop pickers only return a path.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return true;
  }

  /// Where recordings left unexported go when the player closes.
  static Directory folder(AppPaths paths) => paths.directory('diagnostics');

  /// Keeps an unexported recording rather than losing it with the player,
  /// along with the [keep] most recent before it.
  static Future<File> keep(
    String json,
    AppPaths paths,
    DateTime at, {
    int keep = 10,
  }) async {
    final dir = await folder(paths).create(recursive: true);
    final file = File(
      p.join(dir.path, 'stats-${at.millisecondsSinceEpoch}.json'),
    );
    await file.writeAsString(json, flush: true);
    final kept =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => p.basename(f.path).startsWith('stats-'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    for (final old in kept.skip(keep)) {
      await old.delete().catchError((_) => old);
    }
    return file;
  }
}
