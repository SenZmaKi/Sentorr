import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../downloads/manager.dart';
import '../torrents/metadata_identity.dart';
import 'models.dart';

/// [entry]'s torrent metadata already on this device, so it can be checked
/// and recovered offline: its download's own, or the info dictionary its
/// resume state keeps beside the file. Null when neither is there.
Future<Uint8List?> localMetadata(Ref ref, LibraryEntry entry) async {
  final queued = ref
      .read(downloadsProvider)
      .value
      ?.where((d) => d.id == entry.downloadId)
      .firstOrNull
      ?.job
      .torrentData;
  if (queued != null) {
    try {
      validateMetadataIdentity(queued, entry.infoHash);
      return queued;
    } on FormatException {
      // A record from another torrent; the resume state may still match.
    }
  }
  try {
    final resume = resumeFileOf(entry);
    if (!await resume.exists()) return null;
    return metadataFromResume(await resume.readAsBytes(), entry.infoHash);
  } on FileSystemException {
    return null;
  }
}

/// Where the torrent engine keeps [entry]'s torrent's resume state.
File resumeFileOf(LibraryEntry entry) =>
    File(p.join(entry.saveDirectory, '.${entry.infoHash}.resume'));
