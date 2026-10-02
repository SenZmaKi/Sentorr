import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:streaming_lab/engine/lab_session.dart';

Future<void> main(List<String> arguments) async {
  final root = await Directory.systemTemp.createTemp('streaming-native-proof-');
  final input = File('${root.path}/fixture.bin');
  // Larger than the demand window: stall reads must address uncached bytes.
  final expected = Uint8List(64 * 1024 * 1024 + 123);
  for (var i = 0; i < expected.length; i++) {
    expected[i] = (i * 17 + 3) % 251;
  }
  await input.writeAsBytes(expected);
  final events = <Map<String, Object?>>[];
  final lab = LabSession(events.add);
  final checks = <String, Object?>{};
  final client = HttpClient();
  Future<void> read(Uri uri, String range, int start, int end) async {
    final watch = Stopwatch()..start();
    final request = await client.getUrl(uri);
    request.headers.set('Range', range);
    final response = await request.close();
    if (response.statusCode != 206) throw StateError('Expected 206');
    final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
    final reference = expected.sublist(start, end + 1);
    if (bytes.length != reference.length) throw StateError('Wrong length');
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != reference[i]) throw StateError('Byte mismatch at $i');
    }
    checks[range] = {
      'bytes': bytes.length,
      'elapsedMs': watch.elapsedMilliseconds,
    };
  }

  var passed = false;
  try {
    final files = await lab.open(input.path, controlled: true);
    final uri = Uri.parse(await lab.select(files.single['index'] as int));
    await read(uri, 'bytes=131060-262160', 131060, 262160);
    await read(uri, 'bytes=-123', expected.length - 123, expected.length - 1);
    await Future.wait([
      read(uri, 'bytes=2097100-2097200', 2097100, 2097200),
      read(uri, 'bytes=19-99', 19, 99),
    ]);
    lab.pauseSeed(true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    var recovered = false;
    final stalled = read(
      uri,
      'bytes=33554432-33554532',
      33554432,
      33554532,
    ).then((_) => recovered = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (recovered) {
      throw StateError('Unavailable read completed while seed paused');
    }
    checks['stallWaited'] = true;
    lab.pauseSeed(false);
    await stalled.timeout(const Duration(seconds: 35));
    checks['stallRecovered'] = recovered;
    checks['incompleteAtRead'] =
        lab.torrent!.getStatus().totalDone < expected.length;
    if (checks['incompleteAtRead'] != true) {
      throw StateError('Downloaded whole file');
    }
    passed = true;
  } catch (error, stack) {
    checks['error'] = '$error';
    checks['stack'] = '$stack';
  } finally {
    final directory = lab.directory;
    client.close(force: true);
    await lab.close();
    checks['cleanup'] = directory != null && !await directory.exists();
    await root.delete(recursive: true);
    final output = File(
      arguments.isEmpty ? 'validation/native.local.json' : arguments.first,
    );
    await output.parent.create(recursive: true);
    await output.writeAsString(
      const JsonEncoder.withIndent('  ')
          .convert({'passed': passed, 'checks': checks, 'events': events}),
    );
    stdout.writeln(
      'Native torrent/HTTP proof: ${passed ? 'PASS' : 'FAIL'} (${output.path})',
    );
    exitCode = passed ? 0 : 1;
  }
}
