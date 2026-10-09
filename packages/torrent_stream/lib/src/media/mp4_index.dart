import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models.dart';
import 'index_reader.dart';
import 'media_index.dart';
import 'mp4_atoms.dart';
import 'mp4_track.dart';

Future<MediaIndex?> mp4Index(IndexReader reader) async {
  Uint8List? moov;
  final payloads = <DownloadedRange>[];
  for (var offset = 0, boxes = 0; offset + 8 <= reader.length; boxes++) {
    if (boxes > 10000) throw const FormatException('Too many boxes');
    final header = await reader.header(offset);
    final view = ByteData.sublistView(header);
    var size = view.getUint32(0), head = 8;
    final type = ascii.decode(header.sublist(4, 8));
    if (size == 1) {
      size = view.getUint64(8);
      head = 16;
    }
    if (size == 0) size = reader.length - offset;
    if (size < head || offset + size > reader.length) {
      throw const FormatException('Invalid box');
    }
    if (type == 'moov') moov = await reader.read(offset + head, size - head);
    if (type == 'mdat') {
      payloads.add((start: offset + head, end: offset + size));
    }
    if (type == 'moof') {
      return null; // Fragmented indexes need a separate implementation.
    }
    offset += size;
  }
  if (moov == null) return null;
  return _parseTables(moov, payloads);
}

// Keep large sample-table expansion off the engine/HTTP-serving isolate.
Future<MediaIndex?> _parseTables(
  Uint8List moov,
  List<DownloadedRange> payloads,
) => Isolate.run(() => _tables(moov, payloads));

MediaIndex? _tables(Uint8List moov, List<DownloadedRange> payloads) {
  final children = atoms(moov);
  if (children.any((a) => a.type == 'mvex')) return null;
  final movie = atom(children, 'mvhd').view;
  final movieScale = movie.getUint32(movie.getUint8(0) == 1 ? 20 : 12);
  final movieDuration =
      (movie.getUint8(0) == 1 ? movie.getUint64(24) : movie.getUint32(16)) /
      movieScale;
  if (!movieDuration.isFinite || movieDuration <= 0) return null;
  final tracks = [
    for (final trak in children.where((a) => a.type == 'trak'))
      Mp4Track.parse(trak, movieScale),
  ];
  final videos = tracks.where((t) => t.kind == 'vide').toList();
  if (videos.length != 1 || videos.single.samples.isEmpty) return null;
  final video = videos.single.samples;
  final videoEnd = math.min(
    movieDuration,
    videos.single.presentationEnd ?? movieDuration,
  );
  final audio = tracks.where((t) => t.kind == 'soun').toList();
  // Audio presentation ordering must be monotonic for the interval sweep.
  for (final track in audio) {
    for (var n = 1; n < track.samples.length; n++) {
      if (track.samples[n].start < track.samples[n - 1].start) return null;
    }
  }
  for (final track in tracks) {
    if (track.samples.any(
      (s) => !payloads.any(
        (p) => s.bytes.start >= p.start && s.bytes.end <= p.end,
      ),
    )) {
      return null;
    }
  }
  final cursors = List<int>.filled(audio.length, 0);
  final intervals = <MediaInterval>[];
  for (var first = 0; first < video.length;) {
    if (!video[first].sync) return null;
    var last = first + 1;
    while (last < video.length && !video[last].sync) {
      last++;
    }
    var start = video[first].start, end = video[first].end;
    final bytes = <DownloadedRange>[];
    for (var n = first; n < last; n++) {
      start = math.min(start, video[n].start);
      end = math.max(end, video[n].end);
      bytes.add(video[n].bytes);
    }
    for (var t = 0; t < audio.length; t++) {
      final samples = audio[t].samples;
      while (cursors[t] < samples.length && samples[cursors[t]].end <= start) {
        cursors[t]++;
      }
      for (
        var n = cursors[t];
        n < samples.length && samples[n].start < end;
        n++
      ) {
        bytes.add(samples[n].bytes);
      }
    }
    if (end > 0 && start < videoEnd) {
      intervals.add(
        MediaInterval(
          math.max(0, start),
          math.min(end, videoEnd),
          _merge(bytes),
        ),
      );
    }
    first = last;
  }
  if (intervals.isEmpty) return null;
  for (var n = 1; n < intervals.length; n++) {
    if (intervals[n].start + 0.001 < intervals[n - 1].end) return null;
  }
  return MediaIndex(movieDuration, List.unmodifiable(intervals));
}

List<DownloadedRange> _merge(List<DownloadedRange> bytes) {
  bytes.sort((a, b) => a.start.compareTo(b.start));
  final result = <DownloadedRange>[];
  for (final range in bytes) {
    if (result.isNotEmpty && range.start <= result.last.end) {
      final previous = result.removeLast();
      result.add((
        start: previous.start,
        end: math.max(previous.end, range.end),
      ));
    } else {
      result.add(range);
    }
  }
  return List.unmodifiable(result);
}
