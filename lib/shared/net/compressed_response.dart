import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// HTTP/2 supplies encoded payload bytes, unlike HttpClient's automatic gzip
/// decoding. Preserve the response's close hook and decode before Dio parses it.
ResponseBody decodeCompressedResponse(ResponseBody body) {
  final encoding = body.headers[HttpHeaders.contentEncodingHeader]
      ?.join(',')
      .trim()
      .toLowerCase();
  if (encoding != 'gzip' && encoding != 'x-gzip') return body;
  body.stream = _gzipBody(body.stream);
  body.headers.remove(HttpHeaders.contentEncodingHeader);
  body.headers.remove(HttpHeaders.contentLengthHeader);
  return body;
}

Stream<Uint8List> _gzipBody(Stream<Uint8List> input) async* {
  final reader = StreamIterator(input);
  final prefix = BytesBuilder(copy: false);
  try {
    while (prefix.length < 2 && await reader.moveNext()) {
      prefix.add(reader.current);
    }
    final head = prefix.takeBytes();
    Stream<Uint8List> remaining() async* {
      if (head.isNotEmpty) yield head;
      while (await reader.moveNext()) {
        yield reader.current;
      }
    }

    // Http2Adapter may have used its HTTP/1 fallback, whose HttpClient already
    // decoded gzip but retained the header. Sniff even across split chunks.
    if (head.length >= 2 && head[0] == 0x1f && head[1] == 0x8b) {
      yield* gzip.decoder.bind(remaining()).map(Uint8List.fromList);
    } else {
      yield* remaining();
    }
  } finally {
    await reader.cancel();
  }
}
