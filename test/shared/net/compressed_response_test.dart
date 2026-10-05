import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sentorr/shared/net/compressed_response.dart';
import 'package:test/test.dart';

void main() {
  test(
    'decodes gzip with magic split across chunks before text parsing',
    () async {
      final content = utf8.encode(
        '<table class="torrent-list">metadata</table>',
      );
      final encoded = gzip.encode(content);
      final body = ResponseBody(
        Stream.fromIterable([
          Uint8List.fromList(encoded.sublist(0, 1)),
          Uint8List.fromList(encoded.sublist(1, 2)),
          Uint8List.fromList(encoded.sublist(2)),
        ]),
        200,
        headers: {
          'content-encoding': ['gzip'],
          'content-length': ['${encoded.length}'],
        },
      );
      final response = decodeCompressedResponse(body);
      final bytes = await response.stream.expand((chunk) => chunk).toList();
      expect(bytes, content);
      expect(response.headers.containsKey('content-encoding'), false);
      expect(response.headers.containsKey('content-length'), false);
    },
  );

  test('HTTP/1 fallback bytes are not decoded twice', () async {
    final body = ResponseBody.fromString(
      'd4:infodee',
      200,
      headers: {
        'content-encoding': ['gzip'],
      },
    );
    final response = decodeCompressedResponse(body);
    expect(await utf8.decoder.bind(response.stream).join(), 'd4:infodee');
  });

  test('empty and unencoded responses pass through', () async {
    final plain = ResponseBody.fromString('d4:infodee', 200);
    expect(decodeCompressedResponse(plain), same(plain));
    final empty = ResponseBody.fromBytes(
      [],
      200,
      headers: {
        'content-encoding': ['gzip'],
      },
    );
    expect(await decodeCompressedResponse(empty).stream.toList(), isEmpty);
  });
}
