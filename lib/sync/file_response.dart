import 'dart:io';

import 'file_version.dart';

/// Sends [file] in answer to [request], honouring a single byte range so
/// the player on the other device can seek.
Future<void> sendFile(HttpRequest request, File file) async {
  final response = request.response;
  final stat = await file.stat();
  final version = '"${fileVersionFromStat(file, stat)}"';
  final expected = request.headers.value(HttpHeaders.ifMatchHeader);
  if (expected != null && expected != version) {
    response.statusCode = HttpStatus.preconditionFailed;
    return response.close();
  }
  response.headers.set(HttpHeaders.etagHeader, version);
  final length = stat.size;
  response.headers
    ..set(HttpHeaders.acceptRangesHeader, 'bytes')
    ..set(HttpHeaders.cacheControlHeader, 'no-store')
    ..contentType = _typeOf(file.path);
  final range = request.method == 'GET'
      ? parseRange(request.headers.value(HttpHeaders.rangeHeader), length)
      : null;
  if (range == unsatisfiable) {
    response
      ..statusCode = HttpStatus.requestedRangeNotSatisfiable
      ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length')
      ..contentLength = 0;
    return response.close();
  }
  final start = range?.start ?? 0, end = range?.end ?? length - 1;
  response.contentLength = length == 0 ? 0 : end - start + 1;
  if (range != null) {
    response
      ..statusCode = HttpStatus.partialContent
      ..headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$length',
      );
  }
  if (request.method == 'GET' && length > 0) {
    await response.addStream(file.openRead(start, end + 1));
  }
  await response.close();
}

/// A range no byte of the file satisfies.
const unsatisfiable = (start: -1, end: -1);

/// The inclusive bytes `bytes=a-b`, `a-` or `-n` asks for; null for the
/// whole file, including headers this does not understand.
({int start, int end})? parseRange(String? header, int length) {
  final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header?.trim() ?? '');
  if (match == null) return null;
  final first = int.tryParse(match[1]!), last = int.tryParse(match[2]!);
  if (first == null && last == null) return null;
  if (first == null) {
    if (last == 0 || length == 0) return unsatisfiable;
    return (start: length - last!.clamp(0, length), end: length - 1);
  }
  if (first >= length || (last != null && last < first)) return unsatisfiable;
  return (
    start: first,
    end: last == null ? length - 1 : last.clamp(0, length - 1),
  );
}

ContentType _typeOf(String path) =>
    switch (path.toLowerCase().split('.').last) {
      'mp4' || 'm4v' => ContentType('video', 'mp4'),
      'mkv' => ContentType('video', 'x-matroska'),
      'webm' => ContentType('video', 'webm'),
      'mov' => ContentType('video', 'quicktime'),
      'avi' => ContentType('video', 'x-msvideo'),
      'ts' => ContentType('video', 'mp2t'),
      _ => ContentType.binary,
    };
