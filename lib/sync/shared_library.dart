import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../downloads/manager.dart';
import '../library/models.dart';
import '../library/notifier.dart';
import 'payload.dart';

/// What this device offers paired devices: its finished downloads whose
/// files are still on disk.
List<PeerMedia> sharedMedia(Ref ref) => [
  for (final e in ref.read(libraryProvider))
    if (_finished(ref, e) case final file?) PeerMedia.of(e, file.lengthSync()),
];

/// [itemId]'s finished file, or null when this device has none to share.
File? sharedFile(Ref ref, String itemId) {
  final entry = ref.read(libraryProvider.notifier).entry(itemId);
  return entry == null ? null : _finished(ref, entry);
}

File? _finished(Ref ref, LibraryEntry entry) {
  final download = ref
      .read(downloadsProvider)
      .value
      ?.where((d) => d.id == entry.downloadId)
      .firstOrNull;
  if (offlineStateOf(entry, download) is! Downloaded) return null;
  final file = File(entry.path);
  return file.existsSync() ? file : null;
}
