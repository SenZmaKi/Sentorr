import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:sentorr/imdb/mappers.dart' as map;
import 'package:sentorr/imdb/website.dart';
import 'package:sentorr/shared/net/net.dart';

/// Diagnostic for the exact current homepage operation, not a replacement
/// for all Electron catalog endpoints. It requires no browser session.
Future<void> main() async {
  final dio = createDio();
  try {
    final response = await dio.get<String>(
      imdbGraphqlUrl,
      queryParameters: {
        'operationName': 'BatchPage_HomeMain',
        'variables': jsonEncode({
          'fanPicksFirst': 30,
          'locale': 'en-US',
          'placement': 'home',
          'topPicksFirst': 30,
          'topTenFirst': 10,
        }),
        'extensions': jsonEncode({
          'persistedQuery': {
            'sha256Hash':
                Platform.environment['IMDB_HOMEPAGE_HASH'] ?? imdbHomepageHash,
            'version': 1,
          },
        }),
      },
      options: Options(
        responseType: ResponseType.plain,
        headers: imdbWebsiteHeaders,
      ),
    );
    if (response.statusCode != 200) {
      throw StateError('HTTP ${response.statusCode}');
    }
    final json = jsonDecode(response.data!) as Map<String, dynamic>;
    // GraphQL can return useful sections alongside errors. Surface all errors
    // and validate trending specifically, rather than claiming full success.
    for (final error in (json['errors'] as List? ?? [])) {
      stderr.writeln('Homepage section error: ${jsonEncode(error)}');
    }
    final data = json['data'] as Map<String, dynamic>;
    final trending = data['topMeterTitles'] as Map<String, dynamic>;
    final titles = (trending['edges'] as List)
        .map(
          (edge) => map.title(
            (edge as Map<String, dynamic>)['node'] as Map<String, dynamic>,
          ),
        )
        .toList();
    if (titles.isEmpty) throw StateError('No trending titles returned.');
    for (final title in titles) {
      stdout.writeln('${title.id}\t${title.title}\t${title.rating ?? ""}');
    }
    stdout.writeln(
      'Verified ${titles.length} live homepage trending titles '
      'without cookies or a session ID.',
    );
  } catch (error) {
    stderr.writeln('Homepage probe failed: $error');
    exitCode = 1;
  } finally {
    dio.close(force: true);
  }
}
