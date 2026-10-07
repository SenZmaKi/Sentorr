import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart';
import 'package:sentorr/shared/persistence/app_paths.dart';
import 'package:sentorr/shared/persistence/app_image_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // This integration check uses a real loopback server, not the widget HTTP stub.
  HttpOverrides.global = null;
  test(
    'artwork survives cache disposal and can be loaded without the server',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'sentorr-image-cache-',
      );
      final paths = await AppPaths.initialize(rootDirectory: root);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final url = 'http://127.0.0.1:${server.port}/poster.png';
      server.listen((request) async {
        request.response.headers.set(
          HttpHeaders.cacheControlHeader,
          'max-age=3600',
        );
        request.response.add(Uint8List.fromList([1, 2, 3, 4]));
        await request.response.close();
      });
      try {
        AppImageCache.initialize(paths);
        final file = await AppImageCache.manager.getSingleFile(url);
        expect(file.path.startsWith(paths.imageCacheDirectory.path), isTrue);
        expect(await file.readAsBytes(), Uint8List.fromList([1, 2, 3, 4]));
        await AppImageCache.dispose();
        await server.close(force: true);
        AppImageCache.initialize(paths);
        final cached = await AppImageCache.manager.getFileFromCache(url);
        expect(cached, isNotNull);
        expect(
          await cached!.file.readAsBytes(),
          Uint8List.fromList([1, 2, 3, 4]),
        );
      } finally {
        await server.close(force: true);
        await AppImageCache.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'byte budget selects older artwork and reacts to settings changes',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'sentorr-image-budget-',
      );
      try {
        final paths = await AppPaths.initialize(rootDirectory: root);
        AppImageCache.initialize(paths, maxSizeBytes: 4);
        expect(
          PaintingBinding.instance.imageCache.maximumSizeBytes,
          16 * 1024 * 1024,
        );
        final manager = AppImageCache.manager;
        await manager.putFile(
          'https://example.invalid/old.png',
          Uint8List.fromList([1, 2, 3, 4]),
        );
        await manager.putFile(
          'https://example.invalid/new.png',
          Uint8List.fromList([5, 6, 7, 8]),
        );
        final overBudget = await manager.config.repo.getObjectsOverCapacity(
          manager.config.maxNrOfCacheObjects,
        );
        expect(overBudget.map((object) => object.url), [
          'https://example.invalid/old.png',
        ]);
        AppImageCache.applyMaxSizeBytes(8);
        expect(
          await manager.config.repo.getObjectsOverCapacity(
            manager.config.maxNrOfCacheObjects,
          ),
          isEmpty,
        );
      } finally {
        await AppImageCache.dispose();
        await root.delete(recursive: true);
      }
    },
  );

  test('broken cache metadata is preserved and rebuilt', () async {
    final root = await Directory.systemTemp.createTemp(
      'sentorr-image-metadata-',
    );
    try {
      final paths = await AppPaths.initialize(rootDirectory: root);
      await paths.imageCacheMetadataFile.writeAsString('{broken');
      AppImageCache.initialize(paths);
      expect(await AppImageCache.manager.getFileFromCache('missing'), isNull);
      final preserved = await paths.imageCacheMetadataFile.parent
          .list()
          .where((file) => file.path.endsWith('.corrupt'))
          .toList();
      expect(preserved, hasLength(1));
      expect(await File(preserved.single.path).readAsString(), '{broken');
    } finally {
      await AppImageCache.dispose();
      await root.delete(recursive: true);
    }
  });
}
