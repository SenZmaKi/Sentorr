import 'dart:typed_data';

import 'cancellation.dart';

abstract class ByteSource {
  String get name;
  int get length;
  Future<Uint8List> read(int offset, int count, Cancellation cancellation);
  void release(Cancellation cancellation);
}
