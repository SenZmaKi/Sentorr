import 'dart:typed_data';

import '../models.dart';
import 'mp4_atoms.dart';

class MediaSample {
  const MediaSample(this.start, this.end, this.bytes, this.sync);
  final double start, end;
  final DownloadedRange bytes;
  final bool sync;
}

class Mp4Track {
  Mp4Track(this.kind, this.samples, [this.presentationEnd]);
  final String kind;
  final List<MediaSample> samples;
  final double? presentationEnd;

  static Mp4Track parse(Atom trak, int movieScale) {
    final children = atoms(trak.data);
    final mdia = atoms(atom(children, 'mdia').data);
    final mdhd = atom(mdia, 'mdhd').view;
    final scale = mdhd.getUint32(mdhd.getUint8(0) == 1 ? 20 : 12);
    if (scale == 0) throw const FormatException('Invalid timescale');
    var shift = 0.0;
    double? presentationEnd;
    var gap = 0.0;
    final edits = children.where((a) => a.type == 'edts').firstOrNull;
    if (edits != null) {
      final edit = atom(atoms(edits.data), 'elst').view;
      final version = edit.getUint8(0), count = edit.getUint32(4);
      if (version > 1 || count < 1 || count > 2 || movieScale <= 0) {
        throw const FormatException('Unsupported edits');
      }
      final stride = version == 1 ? 20 : 12;
      for (var n = 0; n < count; n++) {
        final pos = 8 + n * stride;
        final duration = version == 1
            ? edit.getUint64(pos)
            : edit.getUint32(pos);
        final time = version == 1
            ? edit.getInt64(pos + 8)
            : edit.getInt32(pos + 4);
        final rate = pos + (version == 1 ? 16 : 8);
        if (edit.getInt16(rate) != 1 || edit.getInt16(rate + 2) != 0) {
          throw const FormatException('Edit rate');
        }
        if (time == -1 && n == 0 && count == 2) {
          gap += duration / movieScale;
          shift += duration / movieScale;
        } else if (time >= 0 && n == count - 1) {
          shift -= time / scale;
          presentationEnd = gap + duration / movieScale;
        } else {
          throw const FormatException('Unsupported edits');
        }
      }
    }
    final handler = atom(mdia, 'hdlr').data;
    final kind = String.fromCharCodes(handler.sublist(8, 12));
    if (kind != 'vide' && kind != 'soun') return Mp4Track(kind, const []);
    final tables = atoms(atom(atoms(atom(mdia, 'minf').data), 'stbl').data);
    final sizes = atom(tables, 'stsz').view;
    final count = sizes.getUint32(8);
    if (count > 1000000) throw const FormatException('Too many samples');
    final fixed = sizes.getUint32(4);
    final lengths = [
      for (var n = 0; n < count; n++)
        fixed == 0 ? sizes.getUint32(12 + n * 4) : fixed,
    ];
    final times = _expand(atom(tables, 'stts').view, count, signed: false);
    final composition = tables.where((a) => a.type == 'ctts').firstOrNull;
    final offsets = composition == null
        ? List<int>.filled(count, 0)
        : _expand(
            composition.view,
            count,
            signed: composition.view.getUint8(0) == 1,
          );
    final syncTable = tables.where((a) => a.type == 'stss').firstOrNull?.view;
    final sync = syncTable == null
        ? null
        : <int>{
            for (var n = 0; n < syncTable.getUint32(4); n++)
              syncTable.getUint32(8 + n * 4) - 1,
          };
    final chunk = tables
        .where((a) => a.type == 'stco' || a.type == 'co64')
        .firstOrNull;
    if (chunk == null) throw const FormatException('Missing chunk offsets');
    final positions = chunk.view;
    final chunkCount = positions.getUint32(4);
    final mapping = atom(tables, 'stsc').view;
    final entries = mapping.getUint32(4);
    if (entries == 0 || mapping.getUint32(8) != 1) {
      throw const FormatException('Invalid chunks');
    }
    var entry = 0, sample = 0, clock = 0;
    final samples = <MediaSample>[];
    for (var n = 0; n < chunkCount; n++) {
      while (entry + 1 < entries &&
          mapping.getUint32(8 + (entry + 1) * 12) <= n + 1) {
        entry++;
      }
      if (mapping.getUint32(16 + entry * 12) != 1) {
        throw const FormatException('Changing sample descriptions');
      }
      final perChunk = mapping.getUint32(12 + entry * 12);
      var position = chunk.type == 'co64'
          ? positions.getUint64(8 + n * 8)
          : positions.getUint32(8 + n * 4);
      if (perChunk == 0 || sample + perChunk > count) {
        throw const FormatException('Invalid samples');
      }
      for (var k = 0; k < perChunk; k++, sample++) {
        final start = (clock + offsets[sample]) / scale + shift;
        samples.add(
          MediaSample(start, start + times[sample] / scale, (
            start: position,
            end: position + lengths[sample],
          ), sync == null || sync.contains(sample)),
        );
        clock += times[sample];
        position += lengths[sample];
      }
    }
    if (sample != count) throw const FormatException('Incomplete samples');
    return Mp4Track(kind, samples, presentationEnd);
  }
}

List<int> _expand(ByteData table, int count, {required bool signed}) {
  final result = <int>[];
  final entries = table.getUint32(4);
  for (var n = 0; n < entries; n++) {
    final repeat = table.getUint32(8 + n * 8);
    final value = signed
        ? table.getInt32(12 + n * 8)
        : table.getUint32(12 + n * 8);
    if (result.length + repeat > count) {
      throw const FormatException('Invalid sample times');
    }
    result.addAll(List<int>.filled(repeat, value));
  }
  if (result.length != count) {
    throw const FormatException('Incomplete sample times');
  }
  return result;
}
