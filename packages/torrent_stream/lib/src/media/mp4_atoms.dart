import 'dart:convert';
import 'dart:typed_data';

class Atom {
  Atom(this.type, this.data);
  final String type;
  final Uint8List data;
  ByteData get view => ByteData.sublistView(data);
}

List<Atom> atoms(Uint8List bytes) {
  final result = <Atom>[];
  final view = ByteData.sublistView(bytes);
  for (var offset = 0; offset + 8 <= bytes.length;) {
    var size = view.getUint32(offset);
    var header = 8;
    if (size == 1) {
      size = view.getUint64(offset + 8);
      header = 16;
    }
    if (size == 0) size = bytes.length - offset;
    if (size < header ||
        offset + size > bytes.length ||
        result.length > 100000) {
      throw const FormatException('Invalid MP4 atom');
    }
    result.add(
      Atom(
        ascii.decode(bytes.sublist(offset + 4, offset + 8)),
        Uint8List.sublistView(bytes, offset + header, offset + size),
      ),
    );
    offset += size;
  }
  return result;
}

Atom atom(List<Atom> values, String type) => values.firstWhere(
  (a) => a.type == type,
  orElse: () => throw FormatException('Missing $type'),
);
