import 'dart:typed_data';

class Element {
  const Element(this.id, this.start, this.end);
  final int id, start, end;
}

({int value, int width, bool unknown}) vint(
  Uint8List data,
  int offset, {
  bool id = false,
}) {
  final first = data[offset];
  var mask = 0x80, width = 1;
  while (width <= 8 && first & mask == 0) {
    mask >>= 1;
    width++;
  }
  if (width > (id ? 4 : 8) || offset + width > data.length) {
    throw const FormatException('Invalid EBML integer');
  }
  var value = id ? first : first & (mask - 1);
  var unknown = !id && value == mask - 1;
  for (var n = 1; n < width; n++) {
    value = (value << 8) | data[offset + n];
    unknown = unknown && data[offset + n] == 255;
  }
  return (value: value, width: width, unknown: unknown);
}

Element element(Uint8List bytes, int offset, {int? limit}) {
  final id = vint(bytes, offset, id: true);
  final size = vint(bytes, offset + id.width);
  final start = offset + id.width + size.width;
  final end = size.unknown ? limit ?? bytes.length : start + size.value;
  if (end > (limit ?? bytes.length) || end < start) {
    throw const FormatException('Invalid EBML size');
  }
  return Element(id.value, start, end);
}

Iterable<Element> elements(Uint8List bytes) sync* {
  for (var pos = 0, count = 0; pos < bytes.length; count++) {
    if (count > 1000000) throw const FormatException('Too many EBML elements');
    final entry = element(bytes, pos);
    yield entry;
    pos = entry.end;
  }
}

int unsigned(Uint8List bytes) {
  if (bytes.length > 8) throw const FormatException('Invalid EBML value');
  var value = 0;
  for (final byte in bytes) {
    value = (value << 8) | byte;
  }
  return value;
}

Uint8List body(Uint8List bytes, Element element) =>
    Uint8List.sublistView(bytes, element.start, element.end);
