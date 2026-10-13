import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:libtorrent_dart/libtorrent_dart_ffi.dart' as native;

Uint8List readResumeData(TorrentHandle handle, {int flags = 0}) =>
    readResumeBuffer(
      (buffer, capacity, length) => native.torrent_get_resume_data(
        handle.id,
        buffer.cast<Char>(),
        capacity,
        length,
        flags,
      ),
    );

/// Each native call takes a new snapshot. A growing snapshot is truncated by
/// native code, so retry instead of reading beyond the allocated buffer.
/// Kept here until the published binding handles changing snapshot lengths.
Uint8List readResumeBuffer(
  int Function(Pointer<Uint8>, int, Pointer<Int32>) read,
) {
  final length = calloc<Int32>();
  try {
    if (read(nullptr, 0, length) != 0) {
      throw StateError('Could not measure torrent resume data');
    }
    var capacity = length.value;
    if (capacity <= 0) return Uint8List(0);
    for (var attempt = 0; attempt < 8; attempt++) {
      final buffer = calloc<Uint8>(capacity);
      try {
        if (read(buffer, capacity, length) != 0 || length.value < 0) {
          throw StateError('Could not read torrent resume data');
        }
        if (length.value <= capacity) {
          return Uint8List.fromList(buffer.asTypedList(length.value));
        }
        capacity = length.value * 2;
      } finally {
        calloc.free(buffer);
      }
    }
    throw StateError('Torrent resume data kept growing');
  } finally {
    calloc.free(length);
  }
}
