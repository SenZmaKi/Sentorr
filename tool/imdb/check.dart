import 'dart:io';

import 'package:dio/dio.dart';
import 'package:sentorr/imdb/repository.dart';
import 'package:sentorr/shared/net/net.dart';

Future<void> main(List<String> args) async {
  final dio = createDio();
  try {
    final repository = ImdbRepository(dio);
    final operation = args.isEmpty ? 'trending' : args.first;
    final titles = switch (operation) {
      'trending' => await repository.trendingTitles(),
      'suggest' => await repository.suggestTitles(
        args.length > 1 ? args[1] : 'matrix',
      ),
      _ => throw ArgumentError('Use trending or suggest [term].'),
    };
    if (titles.isEmpty) throw StateError('IMDb returned no titles.');
    for (final title in titles) {
      stdout.writeln('${title.id}\t${title.title}\t${title.releaseYear ?? ""}');
    }
    stdout.writeln('Verified ${titles.length} titles from live IMDb.');
  } catch (error) {
    stderr.writeln('IMDb live check failed: $error');
    if (error is DioException && error.response?.data != null) {
      stderr.writeln(error.response!.data);
    }
    exitCode = 1;
  } finally {
    dio.close(force: true);
  }
}
