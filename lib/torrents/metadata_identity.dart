import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Checks raw bencode framing and hashes the original info bytes. No native
/// library is loaded here; full torrent semantics remain the engine's job.
void validateMetadataIdentity(Uint8List bytes, String expectedHash) {
  final reader = _Bencode(bytes);
  if (reader.byte != 100) throw const FormatException('Expected dictionary');
  reader.offset++;
  Uint8List? info;
  while (reader.byte != 101) {
    final key = reader.string();
    final start = reader.offset;
    if (ascii.decode(key, allowInvalid: true) == 'info') {
      if (info != null || reader.byte != 100) {
        throw const FormatException('Invalid info dictionary');
      }
      reader.value(1);
      info = Uint8List.sublistView(bytes, start, reader.offset);
    } else {
      reader.value(1);
    }
  }
  reader.offset++;
  if (reader.offset != bytes.length ||
      info == null ||
      sha1.convert(info).toString() != expectedHash.toLowerCase()) {
    throw const FormatException(
      'Torrent info hash mismatch or invalid framing',
    );
  }
}

class _Bencode {
  _Bencode(this.bytes);
  final Uint8List bytes;
  int offset = 0;
  int get byte {
    if (offset >= bytes.length) {
      throw const FormatException('Truncated bencode');
    }
    return bytes[offset];
  }

  Uint8List string() {
    final start = offset;
    while (byte >= 48 && byte <= 57) {
      offset++;
    }
    if (offset == start ||
        byte != 58 ||
        (offset - start > 1 && bytes[start] == 48)) {
      throw const FormatException('Invalid bencode string length');
    }
    final length = int.tryParse(ascii.decode(bytes.sublist(start, offset)));
    offset++;
    if (length == null || length > bytes.length - offset) {
      throw const FormatException('Truncated bencode string');
    }
    final result = Uint8List.sublistView(bytes, offset, offset + length);
    offset += length;
    return result;
  }

  void value(int depth) {
    if (depth > 64) throw const FormatException('Bencode nesting limit');
    if (byte == 100 || byte == 108) {
      final dictionary = byte == 100;
      offset++;
      while (byte != 101) {
        if (dictionary) string();
        value(depth + 1);
      }
      offset++;
    } else if (byte == 105) {
      offset++;
      final start = offset;
      while (byte != 101) {
        offset++;
      }
      final integer = ascii.decode(
        bytes.sublist(start, offset),
        allowInvalid: true,
      );
      if (!RegExp(r'^(0|-?[1-9][0-9]*)$').hasMatch(integer)) {
        throw const FormatException('Invalid bencode integer');
      }
      offset++;
    } else {
      string();
    }
  }
}
