import 'dart:ffi';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/resume_buffer.dart';

void main() {
  test('retries a growing snapshot and returns only complete bytes', () {
    var calls = 0;
    final result = readResumeBuffer((buffer, capacity, length) {
      calls++;
      final bytes = Uint8List.fromList(calls == 1 ? [1] : [2, 3, 4]);
      length.value = bytes.length;
      if (capacity > 0) {
        buffer.asTypedList(capacity).setAll(0, bytes.take(capacity));
      }
      return 0;
    });
    expect(calls, 3);
    expect(result, [2, 3, 4]);
  });

  test('a shrinking snapshot excludes unused buffer bytes', () {
    final result = readResumeBuffer((buffer, capacity, length) {
      length.value = capacity == 0 ? 10 : 1;
      if (capacity > 0) buffer.value = 42;
      return 0;
    });
    expect(result, [42]);
  });

  test('native failure is surfaced', () {
    expect(() => readResumeBuffer((_, _, _) => -1), throwsStateError);
  });

  test('repeated growth has a bounded retry count', () {
    var calls = 0;
    expect(
      () => readResumeBuffer((_, capacity, length) {
        calls++;
        length.value = capacity + 1;
        return 0;
      }),
      throwsStateError,
    );
    expect(calls, 9);
  });
}
