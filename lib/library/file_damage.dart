import 'dart:io';

/// The first bytes every Matroska/WebM file starts with: an EBML header.
const _ebml = [0x1A, 0x45, 0xDF, 0xA3];

/// A zeroed MP4 prefix or a Matroska file without its EBML header is damaged
/// storage, not an unsupported video codec. Other decoder failures remain
/// ambiguous until torrent verification runs.
bool hasMissingHeader(String path, {String? mediaName}) {
  final name = (mediaName ?? path).toLowerCase();
  final matroska = name.endsWith('.mkv') || name.endsWith('.webm');
  if (!matroska && !name.endsWith('.mp4')) return false;
  RandomAccessFile? input;
  try {
    input = File(path).openSync();
    final bytes = input.readSync(32);
    if (matroska) {
      if (bytes.length < _ebml.length) return true;
      for (var i = 0; i < _ebml.length; i++) {
        if (bytes[i] != _ebml[i]) return true;
      }
      return false;
    }
    return bytes.length < 8 || bytes.every((b) => b == 0);
  } on FileSystemException {
    return true;
  } finally {
    input?.closeSync();
  }
}
