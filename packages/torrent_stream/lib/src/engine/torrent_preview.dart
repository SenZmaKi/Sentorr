part of 'torrent_bytes.dart';

extension TorrentPreview on TorrentBytes {
  /// Verified pieces only: no scheduler demand, read-ahead or startup changes.
  Future<Uint8List> readAvailable(
    int offset,
    int count,
    Cancellation cancellation,
  ) async {
    if (offset < 0 || count < 0 || offset + count > length) {
      throw RangeError('Read outside selected file');
    }
    final first = (file.offset + offset) ~/ pieceLength;
    final last = (file.offset + offset + count - 1) ~/ pieceLength;
    for (var piece = first; piece <= last; piece++) {
      if (!(isReadable?.call(piece) ?? handle.havePiece(piece))) {
        throw StateError('Preview piece unavailable');
      }
    }
    if (readRange case final read?) {
      final output = Uint8List(count);
      for (var copied = 0; copied < count;) {
        cancellation.check();
        final take = min(64 * 1024, count - copied);
        final bytes = await read(offset + copied, take, cancellation);
        output.setRange(copied, copied + take, bytes);
        copied += take;
      }
      return output;
    }
    final output = Uint8List(count);
    for (var copied = 0; copied < count;) {
      cancellation.check();
      final absolute = file.offset + offset + copied;
      final piece = absolute ~/ pieceLength;
      // Do not join playback's cached/in-flight reads or their cancellation.
      final cached = _previewPiece;
      final data = cached?.$1 == piece
          ? cached!.$2
          : await readPiece(piece, cancellation);
      cancellation.check();
      if (data.length <= 4 * 1024 * 1024) _previewPiece = (piece, data);
      final within = absolute % pieceLength;
      final take = min(count - copied, data.length - within);
      if (take <= 0) throw StateError('Invalid native piece layout');
      output.setRange(copied, copied + take, data, within);
      copied += take;
    }
    return output;
  }
}
