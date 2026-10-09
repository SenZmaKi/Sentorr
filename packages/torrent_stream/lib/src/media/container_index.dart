import 'dart:typed_data';

import 'avi_index.dart';
import 'index_reader.dart';
import 'media_index.dart';
import 'mkv_index.dart';
import 'mp4_index.dart';

/// Recognize by bytes, not extension. Unknown and unsupported layouts don't
/// produce proportional timestamp guesses.
Future<MediaIndex?> containerIndex(
  int length,
  Future<Uint8List> Function(int, int) read,
) async {
  if (length < 16) return null;
  final reader = IndexReader(length, read);
  try {
    final first = await reader.header(0);
    if (ByteData.sublistView(first).getUint32(0) == 0x1a45dfa3) {
      return await mkvIndex(reader);
    }
    final tag = String.fromCharCodes(first.sublist(4, 8));
    if (String.fromCharCodes(first.sublist(0, 4)) == 'RIFF') {
      return await aviIndex(reader);
    }
    if (['ftyp', 'moov', 'mdat', 'wide', 'free', 'skip'].contains(tag)) {
      return await mp4Index(reader);
    }
  } on FormatException {
    return null;
  } on RangeError {
    return null;
  } on StateError {
    return null;
  }
  return null;
}
