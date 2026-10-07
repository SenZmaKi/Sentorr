import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/shared/graphics_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('macOS sends the native graphics budget as an integer', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.skia, (call) async {
          calls.add(call);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.skia, null),
    );
    await configureGraphicsCache();
    expect(calls.single.method, 'Skia.setResourceCacheMaxBytes');
    expect(calls.single.arguments, 32 * 1024 * 1024);
  });

  test('other renderers keep their platform cache defaults', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.skia,
          (_) async => throw StateError('Unexpected call'),
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.skia, null),
    );
    await configureGraphicsCache();
  });
}
