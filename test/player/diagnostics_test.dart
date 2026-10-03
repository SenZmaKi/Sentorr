import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/diagnostics.dart';

void main() {
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
