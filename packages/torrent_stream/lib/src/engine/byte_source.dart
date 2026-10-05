import 'dart:typed_data';

import 'cancellation.dart';

abstract class ByteSource {
  String get name;
  int get length;

  /// Returned bytes may be read-only views; callers must not mutate them.
  Future<Uint8List> read(int offset, int count, Cancellation cancellation);
  void release(Cancellation cancellation);
}
