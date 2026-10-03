import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/shared/net/net.dart';
import 'package:sentorr/shared/persistence/app_paths.dart';
import 'package:sentorr/shared/source_directory/models.dart';
import 'package:sentorr/shared/source_directory/repository.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:test/test.dart';

void main() {
  test(
    'cache, ETag, rollback and failed refresh preserve the accepted directory',
    () async {
      final root = await Directory.systemTemp.createTemp('sentorr-directory-');
      final paths = await AppPaths.initialize(rootDirectory: root);
      final network = NetworkClient(http2: false, logging: false);
      final requests = <RequestOptions>[];
      var version = 2, status = 200;
      network.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            requests.add(o);
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: status,
                headers: Headers.fromMap({
                  'etag': ['v2'],
                }),
                data: jsonEncode({'version': version}),
              ),
            );
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appPathsProvider.overrideWithValue(paths),
          networkClientProvider.overrideWithValue(network),
          sourceDirectoryProvider.overrideWith(
            () => SourceDirectoryController(
              decode: (envelope) async {
                final n = (jsonDecode(envelope) as Map)['version'] as int;
                if (n < 1) throw const FormatException('Invalid test envelope');
                return SourceDirectory(
                  n,
                  DateTime.now().add(const Duration(days: 1)),
                  SourceDirectory.defaults().endpoints,
                );
              },
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await network.close();
        await root.delete(recursive: true);
      });
      final controller = container.read(sourceDirectoryProvider.notifier);
      await controller.initialize();
      await controller.waitForRefresh();
      expect(container.read(sourceDirectoryProvider).version, 2);
      expect(requests.first.headers.containsKey('If-None-Match'), isFalse);
      expect(await paths.sourceDirectoryFile.exists(), isTrue);
      version = 1;
      await controller.refresh();
      expect(container.read(sourceDirectoryProvider).version, 2);
      expect(requests.last.headers['If-None-Match'], 'v2');
      expect(
        (jsonDecode(await paths.sourceDirectoryFile.readAsString())
            as Map)['version'],
        2,
      );
      version = 0;
      await controller.refresh();
      expect(
        controller.endpointFor(TorrentSourceId.pirateBay),
        'https://apibay.org/q.php',
      );
      expect(container.read(sourceDirectoryProvider).version, 2);
      status = 304;
      await controller.refresh();
      expect(container.read(sourceDirectoryProvider).version, 2);
    },
  );
}
