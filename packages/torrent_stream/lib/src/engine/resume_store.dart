import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'files.dart';
import 'torrent_entry.dart';

File resumeFile(String directory, String hash) =>
    File(p.join(directory, '.$hash.resume'));

// libtorrent's storage key is SHA-1 or the first 20 bytes of a v2 SHA-256.
File partFile(String directory, String hash) =>
    File(p.join(directory, '.${hash.substring(0, 40)}.parts'));

Future<void> saveResume(TorrentEntry entry) async {
  final file = resumeFile(entry.savePath, entry.infoHash);
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsBytes(
    entry.handle.getResumeData(flags: 2),
    flush: true,
  );
  await temporary.rename(file.path);
}

/// Older streams kept partfiles without the native piece bitmap. The POSIX
/// storage backend does not discover partfiles in its ordinary file recheck.
/// Import their slots through addPiece so libtorrent hash-verifies every byte.
Future<void> restoreLegacyParts(TorrentEntry entry) async {
  final file = partFile(entry.savePath, storageHash(entry));
  if (!await file.exists()) return;
  final input = await file.open();
  try {
    final prefix = await input.read(8);
    if (prefix.length != 8) return;
    final header = ByteData.sublistView(prefix);
    final count = header.getUint32(0), size = header.getUint32(4);
    if (count != entry.handle.numPieces || size != entry.handle.pieceLength) {
      return;
    }
    final slots = await input.read(count * 4);
    if (slots.length != count * 4) return;
    final map = ByteData.sublistView(slots);
    final offset = ((8 + count * 4 + 1023) ~/ 1024) * 1024;
    final total = entry.files.fold<int>(0, (sum, f) => sum + f.size);
    final length = await input.length();
    await waitUntil(entry.lifetime, () {
      final state = entry.handle.getStatus().state;
      return state != 1 && state != 7;
    });
    final pending = <int>[];
    Future<void> verifyPending() async {
      // Corrupt slots fail native hashing and remain unavailable. Bound that
      // wait rather than letting a damaged cache prevent playback forever.
      try {
        await waitUntil(entry.lifetime, () {
          pending.removeWhere(entry.handle.havePiece);
          return pending.isEmpty;
        }).timeout(const Duration(seconds: 5));
      } on TimeoutException {
        entry.lifetime.check();
        pending.clear();
      }
    }

    for (var piece = 0; piece < count; piece++) {
      entry.lifetime.check();
      final slot = map.getUint32(piece * 4);
      if (slot >= count || entry.handle.havePiece(piece)) continue;
      final bytes = min(size, total - piece * size);
      final start = offset + slot * size;
      if (bytes <= 0 || start + bytes > length) continue;
      await input.setPosition(start);
      entry.handle.addPiece(piece, await input.read(bytes));
      pending.add(piece);
      // Bound queued native buffers when importing a large retained torrent.
      if (pending.length == 8) await verifyPending();
    }
    await verifyPending();
    await saveResume(entry);
  } finally {
    await input.close();
  }
}

/// Storage uses the v2 hash for hybrid torrents, while app identity may be v1.
String storageHash(TorrentEntry entry) {
  final reader = _Reader(entry.handle.getResumeData());
  reader.offset++; // Root dictionary.
  Uint8List? v1, v2;
  while (reader.byte != 101) {
    final key = reader.string();
    if (key == 'info-hash' || key == 'info-hash2') {
      final end = reader.stringEnd();
      final hash = reader.bytes.sublist(reader.offset, end);
      reader.offset = end;
      if (key == 'info-hash2') {
        v2 = hash;
      } else {
        v1 = hash;
      }
    } else {
      reader.skip();
    }
  }
  final hash = v2 ?? v1;
  if (hash == null || hash.length < 20) return entry.infoHash;
  return hash.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

class _Reader {
  _Reader(this.bytes);
  final Uint8List bytes;
  int offset = 0;
  int get byte => bytes[offset];

  int integer() {
    if (byte != 105) throw const FormatException('Expected integer');
    final start = ++offset;
    while (byte != 101) {
      offset++;
    }
    final value = int.parse(ascii.decode(bytes.sublist(start, offset)));
    offset++;
    return value;
  }

  int stringEnd() {
    final start = offset;
    while (byte != 58) {
      offset++;
    }
    final length = int.parse(ascii.decode(bytes.sublist(start, offset)));
    final end = ++offset + length;
    if (length < 0 || end > bytes.length) {
      throw const FormatException('Invalid string length');
    }
    return end;
  }

  String string() {
    final end = stringEnd();
    final value = ascii.decode(bytes.sublist(offset, end));
    offset = end;
    return value;
  }

  void skip([int depth = 0]) {
    if (depth > 64) throw const FormatException('Metadata too deep');
    switch (byte) {
      case 105:
        integer();
      case 100 || 108:
        offset++;
        while (byte != 101) {
          skip(depth + 1);
        }
        offset++;
      default:
        offset = stringEnd();
    }
  }
}
