import 'dart:io';

/// A zeroed MP4 prefix is damaged storage, not an unsupported video codec.
/// Other decoder failures remain ambiguous until torrent verification runs.
bool hasMissingMp4Header(String path, {String? mediaName}) {
  if (!(mediaName ?? path).toLowerCase().endsWith('.mp4')) return false;
  RandomAccessFile? input;
  try {
    input = File(path).openSync();
    final bytes = input.readSync(32);
    return bytes.length < 8 || bytes.every((b) => b == 0);
  } on FileSystemException {
    return true;
  } finally {
    input?.closeSync();
  }
}
