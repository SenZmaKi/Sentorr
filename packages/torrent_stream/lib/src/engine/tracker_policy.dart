import 'dart:convert';
import 'dart:typed_data';

/// Reads only info.private; large binary fields are skipped without copying.
/// Unreadable metadata must not receive public discovery defaults.
bool isPrivateTorrent(Uint8List bytes) {
  try {
    final reader = _Reader(bytes);
    if (reader.byte != 100) return true;
    reader.offset++;
    var private = false;
    while (reader.byte != 101) {
      final key = reader.string();
      if (key == 'info' && reader.byte == 100) {
        reader.offset++;
        while (reader.byte != 101) {
          final field = reader.string();
          if (field == 'private') {
            private = reader.integer() != 0;
          } else {
            reader.skip();
          }
        }
        reader.offset++;
      } else {
        reader.skip();
      }
    }
    reader.offset++;
    return reader.offset != bytes.length || private;
  } on Object {
    return true;
  }
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
