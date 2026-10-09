import 'dart:math' as math;
import 'dart:typed_data';

import '../models.dart';
import 'index_reader.dart';
import 'media_index.dart';

String _tag(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes.sublist(offset, offset + 4));
int _u32(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint32(offset, Endian.little);

Iterable<({String tag, int start, int end})> _chunks(Uint8List bytes) sync* {
  for (var pos = 0; pos + 8 <= bytes.length;) {
    final end = pos + 8 + _u32(bytes, pos + 4);
    if (end > bytes.length) throw const FormatException('Invalid RIFF chunk');
    yield (tag: _tag(bytes, pos), start: pos + 8, end: end);
    pos = end + (end & 1);
  }
}

class _Stream {
  _Stream(this.kind, this.step, this.sampleSize, this.length);
  final String kind;
  final double step;
  final int sampleSize, length;
  double clock = 0;
  final samples =
      <({double start, double end, bool key, DownloadedRange bytes})>[];
}

/// Classic indexed AVI. OpenDML and indexless files remain unknown.
Future<MediaIndex?> aviIndex(IndexReader reader) async {
  final first = await reader.header(0);
  if (_tag(first, 0) != 'RIFF' || _tag(first, 8) != 'AVI ') return null;
  final limit = _u32(first, 4) + 8;
  if (limit != reader.length) return null; // No multi-RIFF AVIX support yet.
  Uint8List? headers, index;
  int? moviStart, moviEnd;
  for (var pos = 12, count = 0; pos + 8 <= limit; count++) {
    if (count > 10000) return null;
    final h = await reader.header(pos);
    final size = _u32(h, 4), end = pos + 8 + size;
    if (end > limit || end <= pos) return null;
    if (_tag(h, 0) == 'LIST' && size >= 4) {
      if (_tag(h, 8) == 'hdrl') {
        headers = await reader.read(pos + 12, size - 4);
      }
      if (_tag(h, 8) == 'movi') {
        moviStart = pos + 8;
        moviEnd = end;
      }
    }
    if (_tag(h, 0) == 'idx1') index = await reader.read(pos + 8, size);
    pos = end + (end & 1);
  }
  if (headers == null ||
      index == null ||
      moviStart == null ||
      moviEnd == null) {
    return null;
  }
  final streams = <_Stream>[];
  for (final chunk in _chunks(headers)) {
    if (chunk.tag != 'LIST' || _tag(headers, chunk.start) != 'strl') continue;
    final list = Uint8List.sublistView(headers, chunk.start + 4, chunk.end);
    _Stream? stream;
    for (final field in _chunks(list)) {
      if (field.tag == 'indx') return null;
      if (field.tag != 'strh') continue;
      final h = Uint8List.sublistView(list, field.start, field.end);
      if (h.length < 56 || _u32(h, 16) != 0 || _u32(h, 28) != 0) return null;
      final scale = _u32(h, 20), rate = _u32(h, 24);
      if (scale == 0 || rate == 0) return null;
      stream = _Stream(_tag(h, 0), scale / rate, _u32(h, 44), _u32(h, 32));
    }
    if (stream == null) return null;
    streams.add(stream);
  }
  if (streams.where((s) => s.kind == 'vids').length != 1 ||
      index.length % 16 != 0) {
    return null;
  }
  // Validate the index's offset convention against one real chunk header.
  int? base;
  for (var pos = 0; pos < index.length; pos += 16) {
    final tag = _tag(index, pos);
    final id = int.tryParse(tag.substring(0, 2));
    if (id == null || id >= streams.length) continue;
    final offset = _u32(index, pos + 8), size = _u32(index, pos + 12);
    if (base == null) {
      for (final candidate in [moviStart, 0]) {
        final start = candidate + offset;
        if (start < moviStart + 4 || start + 8 + size > moviEnd) continue;
        final h = await reader.header(start);
        if (_tag(h, 0) == tag && _u32(h, 4) == size) {
          base = candidate;
          break;
        }
      }
      if (base == null) return null;
    }
    final start = base + offset, end = start + 8 + size;
    if (start < moviStart + 4 || end > moviEnd) return null;
    final stream = streams[id];
    if (_u32(index, pos + 4) & 0x100 != 0) return null;
    if (stream.kind != 'vids' && stream.kind != 'auds') continue;
    if (stream.sampleSize > 0 && size % stream.sampleSize != 0) return null;
    final units = stream.sampleSize == 0 ? 1 : size ~/ stream.sampleSize;
    final next = stream.clock + units * stream.step;
    stream.samples.add((
      start: stream.clock,
      end: next,
      key: _u32(index, pos + 4) & 0x10 != 0,
      bytes: (start: start, end: end),
    ));
    stream.clock = next;
  }
  final videoStream = streams.singleWhere((s) => s.kind == 'vids');
  final video = videoStream.samples;
  if (video.isEmpty || video.length != videoStream.length) return null;
  for (final stream in streams.where((s) => s.kind == 'auds')) {
    if ((stream.clock / stream.step - stream.length).abs() > 0.01) {
      return null;
    }
  }
  final audio = streams.where((s) => s.kind == 'auds').toList();
  final cursors = List<int>.filled(audio.length, 0);
  final intervals = <MediaInterval>[];
  for (var first = 0; first < video.length;) {
    if (!video[first].key) return null;
    var last = first + 1;
    while (last < video.length && !video[last].key) {
      last++;
    }
    final start = video[first].start, end = video[last - 1].end;
    var previous = first == 0 ? 0 : first - 1;
    while (previous > 0 && !video[previous].key) {
      previous--;
    }
    var following = last < video.length ? last + 1 : last;
    while (following < video.length && !video[following].key) {
      following++;
    }
    final ranges = [for (var n = previous; n < following; n++) video[n].bytes];
    for (var t = 0; t < audio.length; t++) {
      final samples = audio[t].samples;
      while (cursors[t] < samples.length && samples[cursors[t]].end <= start) {
        cursors[t]++;
      }
      for (
        var n = math.max(0, cursors[t] - 1);
        n < samples.length && samples[n].start < end + audio[t].step;
        n++
      ) {
        ranges.add(samples[n].bytes);
      }
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));
    // Whole interleaved region also covers chunk padding and decoder lookahead.
    intervals.add(
      MediaInterval(start, end, [
        (
          start: ranges.first.start,
          end: ranges.map((r) => r.end).reduce(math.max),
        ),
      ]),
    );
    first = last;
  }
  return MediaIndex(videoStream.clock, List.unmodifiable(intervals));
}
