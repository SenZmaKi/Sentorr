import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/diagnostics.dart';

void main() {
  test('counter totals are scoped to the current source', () async {
    var source = 'first', count = 100;
    final diagnostics = PlaybackDiagnostics(
      (_) async => '$count',
      source: () => source,
    );
    await Future<void>.delayed(Duration.zero);
    count = 105;
    await diagnostics.sample();
    expect(diagnostics.values['frame-drop-count'], '5');
    source = 'second';
    await diagnostics.sample();
    expect(diagnostics.values['frame-drop-count'], '0');
    diagnostics.dispose();
  });

  test('a sample crossing a source change is discarded', () async {
    var source = 'first';
    final pending = Completer<String>();
    final diagnostics = PlaybackDiagnostics(
      (_) => pending.future,
      source: () => source,
    );
    source = 'second';
    pending.complete('old');
    await Future<void>.delayed(Duration.zero);
    expect(diagnostics.values, isEmpty);
    diagnostics.dispose();
  });
  test('missing and failed native properties remain unavailable', () async {
    final diagnostics = PlaybackDiagnostics((key) async {
      if (key == 'video-codec') return 'h264';
      if (key == 'frame-drop-count') throw StateError('unsupported');
      return '';
    });
    await Future<void>.delayed(Duration.zero);
    expect(diagnostics.values['video-codec'], 'h264');
    expect(diagnostics.values['frame-drop-count'], 'Unavailable');
    expect(diagnostics.values['hwdec-current'], 'Unavailable');
    diagnostics.dispose();
  });

  test('closing during a sample stops further reads and publication', () async {
    final pending = Completer<String>();
    var reads = 0;
    final diagnostics = PlaybackDiagnostics((_) {
      reads++;
      return pending.future;
    });
    diagnostics.dispose();
    pending.complete('h264');
    await Future<void>.delayed(Duration.zero);
    expect(reads, 1);
    expect(diagnostics.values, isEmpty);
  });
}
