import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';

import 'cancellation.dart';

Future<void> waitUntil(Cancellation lifetime, bool Function() ready) async {
  while (!ready()) {
    lifetime.check();
    await lifetime.wait(
      Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  lifetime.check();
}

/// Lowercase hex info hash of [source], before it is added.
Future<String> infoHashOf(Map source) async {
  switch (source['kind']) {
    case 'magnet':
      return parseMagnetUri(
        source['value'] as String,
      ).infohashHex.toLowerCase();
    case 'file':
      return loadTorrentFile(
        source['value'] as String,
      ).infohashHex.toLowerCase();
    case 'bytes':
      final folder = await Directory.systemTemp.createTemp('torrent-hash-');
      try {
        final file = File('${folder.path}${Platform.pathSeparator}t.torrent');
        await file.writeAsBytes(source['value'] as Uint8List);
        return loadTorrentFile(file.path).infohashHex.toLowerCase();
      } finally {
        await folder.delete(recursive: true);
      }
    default:
      throw ArgumentError('Unsupported torrent source');
  }
}

/// libtorrent removes torrents on its own thread, so a late write can
/// recreate a folder just deleted.
Future<void> deleteSoon(Directory folder) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    try {
      if (await folder.exists()) await folder.delete(recursive: true);
    } on FileSystemException catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!await folder.exists()) return;
  }
}

/// libtorrent moves files on its own thread; a temporary folder goes once
/// no files remain in it.
Future<void> deleteWhenEmptied(Directory folder) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < const Duration(minutes: 10)) {
    try {
      if (!await folder.exists()) return;
      final files = await folder
          .list(recursive: true)
          .where((e) => e is File)
          .isEmpty;
      if (files) {
        await folder.delete(recursive: true);
        return;
      }
    } on FileSystemException catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}
