import 'dart:typed_data';

import 'ebml.dart';
import 'index_reader.dart';
import 'media_index.dart';

Future<MediaIndex?> mkvIndex(IndexReader reader) async {
  Future<Element> header(int offset, int limit) async {
    final bytes = await reader.header(offset);
    final id = vint(bytes, 0, id: true);
    final size = vint(bytes, id.width);
    final start = offset + id.width + size.width;
    final end = size.unknown ? limit : start + size.value;
    if (end > limit || end < start) {
      throw const FormatException('Invalid Matroska element');
    }
    return Element(id.value, start, end);
  }

  final ebml = await header(0, reader.length);
  if (ebml.id != 0x1a45dfa3) return null;
  final segment = await header(ebml.end, reader.length);
  if (segment.id != 0x18538067) return null;
  final locations = <int, Element>{};
  final sought = <int, int>{};
  for (
    var pos = segment.start, count = 0;
    pos < segment.end && count < 64;
    count++
  ) {
    final entry = await header(pos, segment.end);
    locations[entry.id] = entry;
    if (entry.id == 0x114d9b74) {
      final bytes = await reader.read(entry.start, entry.end - entry.start);
      for (final seek in elements(bytes).where((e) => e.id == 0x4dbb)) {
        int? id, position;
        final fields = body(bytes, seek);
        for (final field in elements(fields)) {
          if (field.id == 0x53ab) id = unsigned(body(fields, field));
          if (field.id == 0x53ac) position = unsigned(body(fields, field));
        }
        if (id != null && position != null) {
          sought[id] = segment.start + position;
        }
      }
    }
    if (entry.id == 0x1f43b675) break; // Never scan the media to find an index.
    pos = entry.end;
  }
  for (final id in [0x1549a966, 0x1654ae6b, 0x1c53bb6b]) {
    if (!locations.containsKey(id) && sought.containsKey(id)) {
      final entry = await header(sought[id]!, segment.end);
      if (entry.id != id) return null;
      locations[id] = entry;
    }
  }
  Future<Uint8List> load(int id) async {
    final entry = locations[id];
    if (entry == null) throw const FormatException('Missing Matroska index');
    return reader.read(entry.start, entry.end - entry.start);
  }

  var scale = 1000000, duration = 0.0;
  final info = await load(0x1549a966);
  for (final entry in elements(info)) {
    final value = body(info, entry);
    if (entry.id == 0x2ad7b1) scale = unsigned(value);
    if (entry.id == 0x4489) {
      final view = ByteData.sublistView(value);
      duration = value.length == 4 ? view.getFloat32(0) : view.getFloat64(0);
    }
  }
  duration *= scale / 1e9;
  if (!duration.isFinite || duration <= 0 || scale <= 0) return null;
  final tracks = await load(0x1654ae6b);
  final videoTracks = <int>[];
  var audioLead = 0.0;
  for (final entry in elements(tracks).where((e) => e.id == 0xae)) {
    int? number, type;
    var delay = 0.0, preroll = 0.0;
    final fields = body(tracks, entry);
    for (final field in elements(fields)) {
      if (field.id == 0xd7) number = unsigned(body(fields, field));
      if (field.id == 0x83) type = unsigned(body(fields, field));
      // Track timestamp transformations need explicit handling, not guesses.
      if (field.id == 0x56aa) delay = unsigned(body(fields, field)) / 1e9;
      if (field.id == 0x56bb) preroll = unsigned(body(fields, field)) / 1e9;
      if (field.id == 0x23314f || field.id == 0x537f) {
        return null;
      }
    }
    if (type == 1 && number != null) {
      if (delay != 0 || preroll != 0) return null;
      videoTracks.add(number);
    }
    if (type == 2 && delay + preroll > audioLead) {
      audioLead = delay + preroll;
    }
  }
  if (videoTracks.length != 1) return null;
  final cues = await load(0x1c53bb6b);
  final points = <({double time, int position})>[];
  for (final cue in elements(cues).where((e) => e.id == 0xbb)) {
    final fields = body(cues, cue);
    int? time;
    for (final field in elements(fields)) {
      if (field.id == 0xb3) time = unsigned(body(fields, field));
    }
    if (time == null) return null;
    for (final positions in elements(fields).where((e) => e.id == 0xb7)) {
      int? track, position;
      final values = body(fields, positions);
      for (final value in elements(values)) {
        if (value.id == 0xf7) track = unsigned(body(values, value));
        if (value.id == 0xf1) position = unsigned(body(values, value));
      }
      if (track == videoTracks.single && position != null) {
        final absolute = segment.start + position;
        if (absolute < segment.start || absolute >= segment.end) return null;
        final t = time * scale / 1e9;
        if (points.isNotEmpty && absolute == points.last.position) continue;
        if (points.isNotEmpty &&
            (absolute < points.last.position || t <= points.last.time)) {
          return null;
        }
        points.add((time: t, position: absolute));
      }
    }
  }
  final intervals = <MediaInterval>[];
  // Include neighboring cue intervals to cover interleaved audio at the
  // boundaries, without fetching video payload to build the index. A final cue
  // without a following boundary remains unknown unless the file is complete.
  for (var n = 0; n + 2 < points.length; n++) {
    final a = points[n], b = points[n + 1];
    if (b.time > duration) return null;
    var previous = n == 0 ? 0 : n - 1;
    while (previous > 0 && points[previous].time > a.time - audioLead) {
      previous--;
    }
    var following = n + 2;
    while (following < points.length - 1 &&
        points[following].time < b.time + audioLead) {
      following++;
    }
    if (points[following].time < b.time + audioLead) continue;
    intervals.add(
      MediaInterval(a.time, b.time, [
        (start: points[previous].position, end: points[following].position),
      ]),
    );
  }
  return intervals.isEmpty
      ? null
      : MediaIndex(duration, List.unmodifiable(intervals));
}
