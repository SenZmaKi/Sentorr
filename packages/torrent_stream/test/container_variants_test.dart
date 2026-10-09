import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:torrent_stream/src/media/container_index.dart';
import 'package:torrent_stream/src/media/ebml.dart';
import 'package:torrent_stream/src/media/media_index.dart';

void main() {
  Future<MediaIndex?> load(Uint8List bytes) => containerIndex(
    bytes.length,
    (offset, count) async =>
        Uint8List.sublistView(bytes, offset, offset + count),
  );

  test('legacy MOV without ftyp is recognized by its atom layout', () async {
    final bytes = await File('test/fixtures/media/index.mov').readAsBytes();
    bytes.setRange(4, 8, 'wide'.codeUnits);
    expect(await load(bytes), isNotNull);
  });

  test(
    'AVI absolute offsets work and malformed offsets stay unknown',
    () async {
      final bytes = await File('test/fixtures/media/index.avi').readAsBytes();
      final view = ByteData.sublistView(bytes);
      var movi = 0, index = 0;
      for (var pos = 12; pos + 8 <= bytes.length;) {
        final tag = String.fromCharCodes(bytes.sublist(pos, pos + 4));
        final size = view.getUint32(pos + 4, Endian.little);
        if (tag == 'LIST' &&
            String.fromCharCodes(bytes.sublist(pos + 8, pos + 12)) == 'movi') {
          movi = pos + 8;
        }
        if (tag == 'idx1') index = pos;
        pos += 8 + size + (size & 1);
      }
      expect(movi, greaterThan(0));
      expect(index, greaterThan(0));
      for (var pos = index + 8; pos < bytes.length; pos += 16) {
        view.setUint32(
          pos + 8,
          view.getUint32(pos + 8, Endian.little) + movi,
          Endian.little,
        );
      }
      expect(await load(bytes), isNotNull);
      view.setUint32(index + 16, bytes.length + 1, Endian.little);
      expect(await load(bytes), isNull);
      bytes.setRange(index, index + 4, 'JUNK'.codeUnits);
      expect(await load(bytes), isNull);
    },
  );

  test(
    'Opus seek preroll expands required bytes beyond the prior cue',
    () async {
      final bytes = await File('test/fixtures/media/index.webm').readAsBytes();
      final baseline = await load(bytes);
      final segment = element(bytes, element(bytes, 0).end);
      var changed = false;
      for (var pos = segment.start; pos < segment.end;) {
        final entry = element(bytes, pos);
        if (entry.id == 0x1654ae6b) {
          final tracks = body(bytes, entry);
          for (final track in elements(tracks).where((e) => e.id == 0xae)) {
            final fields = body(tracks, track);
            for (final field in elements(fields).where((e) => e.id == 0x56bb)) {
              final value = body(fields, field);
              var ns = 4000000000;
              expect(value.length, greaterThanOrEqualTo(4));
              for (var n = value.length - 1; n >= 0; n--) {
                value[n] = ns & 255;
                ns >>= 8;
              }
              changed = true;
            }
          }
          break;
        }
        pos = entry.end;
      }
      expect(changed, isTrue);
      final expanded = await load(bytes);
      expect(expanded, isNotNull);
      final before = baseline!.intervals[3];
      final after = expanded!.intervals.firstWhere(
        (i) => i.start == before.start,
      );
      expect(after.bytes.first.start, lessThan(before.bytes.first.start));
      expect(after.bytes.last.end, greaterThan(before.bytes.last.end));
      expect(expanded.available(before.bytes), isEmpty);
    },
  );
}
