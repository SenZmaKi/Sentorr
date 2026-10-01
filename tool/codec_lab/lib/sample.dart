import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class Sample {
  final String title, uri, purpose;
  final Map<String, dynamic> metadata;
  const Sample(this.title, this.uri, this.purpose, this.metadata);

  String get expectedTracks {
    if (metadata.isEmpty) return 'User file: inspect track menus';
    final streams = metadata['streams'] as List? ?? [];
    final audio = streams.where((s) => s['codec_type'] == 'audio').length;
    final subs = streams.where((s) => s['codec_type'] == 'subtitle').length;
    return '${audio == 0 ? "Silent (no audio track)" : "$audio generated test-tone track(s)"} · ${subs == 0 ? "No subtitles" : "$subs embedded subtitles (SRT / ASS)"}';
  }

  static Future<List<Sample>> bundled() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('assets/samples.json')) as List;
    final cache = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'samples-v1'),
    );
    await cache.create(recursive: true);
    final samples = <Sample>[];
    for (final raw in manifest) {
      final data = Map<String, dynamic>.from(raw as Map);
      final file = File(p.join(cache.path, data['file'] as String));
      final expected = data['bytes'] as int;
      if (!await file.exists() || await file.length() != expected) {
        final bytes = await rootBundle.load('assets/media/${data['file']}');
        await file.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
      }
      samples.add(
        Sample(
          data['title'] as String,
          file.path,
          data['purpose'] as String,
          data,
        ),
      );
    }
    return samples;
  }
}
