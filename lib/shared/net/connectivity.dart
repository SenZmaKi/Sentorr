import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

const _probeTimeout = Duration(seconds: 3);
const _dnsProbeHost = 'www.imdb.com';
const _httpProbes = [
  'https://www.gstatic.com/generate_204',
  'https://cloudflare.com/cdn-cgi/trace',
];

/// Whether the device appears to have usable internet access, after
/// Senpwai's probe. DNS alone can pass on captive or broken networks, so a
/// short HTTP probe follows; any response counts.
Future<bool> hasInternet({Duration timeout = _probeTimeout}) async {
  try {
    final addresses = await InternetAddress.lookup(_dnsProbeHost)
        .timeout(timeout);
    if (addresses.isEmpty) return false;
  } on Object {
    return false;
  }
  for (final uri in _httpProbes) {
    if (await _reaches(Uri.parse(uri), timeout)) return true;
  }
  return false;
}

Future<bool> _reaches(Uri uri, Duration timeout) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.headUrl(uri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    unawaited(response.drain<void>());
    return true;
  } on Object {
    return false;
  } finally {
    client.close(force: true);
  }
}

/// [error] means the request never got an answer: no route, DNS or a
/// timeout, as offline looks. Cancellations and HTTP errors do not count.
bool isNetworkFailure(DioException error) {
  if (error.response != null) return false;
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => true,
    DioExceptionType.unknown => error.error is SocketException,
    _ => false,
  };
}
