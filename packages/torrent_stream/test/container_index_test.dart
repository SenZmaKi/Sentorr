import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:torrent_stream/src/media/container_index.dart';
import 'package:torrent_stream/src/media/media_index.dart';
import 'package:torrent_stream/src/media/mp4_atoms.dart';

void main() {
  Future<(MediaIndex?, int)> load(String extension) async {
    final bytes = await File(
      'test/fixtures/media/index.$extension',
    ).readAsBytes();
    var read = 0;
    final index = await containerIndex(bytes.length, (offset, count) async {
      read += count;
      return Uint8List.sublistView(bytes, offset, offset + count);
    });
    return (index, read);
  }

  for (final extension in ['mp4', 'mkv', 'mov', 'webm', 'avi']) {
    test(
      '$extension indexes sparsely and metadata alone never lights up time',
      () async {
        final (index, read) = await load(extension);
        expect(index, isNotNull);
        final map = index!;
        expect(map.duration, closeTo(16, 0.1));
        expect(read, lessThan(80000));
        expect(map.intervals.length, greaterThan(4));
        final length = await File(
          'test/fixtures/media/index.$extension',
        ).length();
        expect(map.available([(start: length - 128, end: length)]), isEmpty);
        final interval = map.intervals[2];
        final result = map.available(interval.bytes);
        expect(
          result.any((r) => r.start <= interval.start && r.end >= interval.end),
          isTrue,
        );
        expect(result.first.start, greaterThan(0));
        expect(map.available(const []), isEmpty);
      },
    );
  }
  for (final extension in ['mp4', 'avi']) {
    test(
      '$extension intervals cover actual video dependencies and audio packet bytes',
      () async {
        final (index, _) = await load(extension);
        final packets =
            (jsonDecode(
                      await File(
                        'test/fixtures/media/${extension}_packets.json',
                      ).readAsString(),
                    )
                    as Map)['packets']
                as List;
        for (final interval in index!.intervals) {
          final relevant = packets.where((raw) {
            final packet = raw as Map;
            final time = double.parse(packet['pts_time'] as String);
            final end = time + double.parse(packet['duration_time'] as String);
            return end > interval.start + 0.0001 &&
                time < interval.end - 0.0001;
          });
          expect(relevant, isNotEmpty);
          for (final raw in relevant) {
            final packet = raw as Map;
            final start = int.parse(packet['pos'] as String);
            final end = start + int.parse(packet['size'] as String);
            expect(
              interval.bytes.any((r) => r.start <= start && r.end >= end),
              isTrue,
              reason:
                  'Missing packet $packet at ${interval.start}-${interval.end}',
            );
          }
        }
      },
    );
  }
  test(
    'malformed and unsupported media stay unknown with bounded reads',
    () async {
      final bytes = Uint8List(32)..setRange(4, 8, 'ftyp'.codeUnits);
      final index = await containerIndex(
        bytes.length,
        (offset, count) async =>
            Uint8List.sublistView(bytes, offset, offset + count),
      );
      expect(index, isNull);
      expect(await containerIndex(0, (_, _) async => Uint8List(0)), isNull);
    },
  );
  test('trimmed MP4 edits exclude discarded video samples', () async {
    final bytes = await File('test/fixtures/media/index.mp4').readAsBytes();
    final movie = atoms(atom(atoms(bytes), 'moov').data);
    final scale = atom(movie, 'mvhd').view.getUint32(12);
    final track = atoms(atom(movie, 'trak').data);
    final edit = atom(atoms(atom(track, 'edts').data), 'elst').view;
    if (edit.getUint8(0) == 0) {
      edit.setUint32(8, scale * 8);
    } else {
      edit.setUint64(8, scale * 8);
    }
    final index = await containerIndex(
      bytes.length,
      (offset, count) async =>
          Uint8List.sublistView(bytes, offset, offset + count),
    );
    expect(index, isNotNull);
    expect(index!.intervals.every((i) => i.end <= 8), isTrue);
    expect(index.duration, closeTo(16, 0.1));
  });
  test('oversized metadata is rejected before downloading its body', () async {
    final bytes = Uint8List(24);
    final view = ByteData.sublistView(bytes);
    view.setUint32(0, 8);
    bytes.setRange(4, 8, 'ftyp'.codeUnits);
    view.setUint32(8, 32 * 1024 * 1024 - 8);
    bytes.setRange(12, 16, 'moov'.codeUnits);
    final requests = <int>[];
    final index = await containerIndex(32 * 1024 * 1024, (offset, count) async {
      requests.add(count);
      return Uint8List.sublistView(bytes, offset, offset + count);
    });
    expect(index, isNull);
    expect(requests.every((count) => count <= 16), isTrue);
  });
}
