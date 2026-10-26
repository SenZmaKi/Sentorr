import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/shared/window_manager.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/shared/persistence/window_state_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('activation cannot show the window before startup reveal', () async {
    final window = WindowManager.getInstance();
    window.dispose();
    final calls = <String>[];
    var permitReveal = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const plugin = MethodChannel('window_manager');
    const startup = MethodChannel('sentorr/startup');
    messenger.setMockMethodCallHandler(plugin, (call) async {
      calls.add(call.method);
      return call.method.startsWith('is') ? false : null;
    });
    messenger.setMockMethodCallHandler(startup, (call) async {
      calls.add(call.method);
      return permitReveal;
    });
    addTearDown(() {
      window.dispose();
      messenger.setMockMethodCallHandler(plugin, null);
      messenger.setMockMethodCallHandler(startup, null);
    });

    await window.focus();
    expect(calls, isEmpty);
    if (Platform.isMacOS) {
      await window.reveal();
      expect(calls, ['ensureInitialized', 'readyToShow']);
      calls.clear();
    }
    permitReveal = true;
    await window.reveal();
    expect(calls, [
      'ensureInitialized',
      if (Platform.isMacOS) 'readyToShow',
      'isMinimized',
      'show',
      'focus',
    ]);
    calls.clear();
    await window.focus();
    expect(calls, ['isMinimized', 'show', 'focus']);
  }, skip: !supportsWindowCustomization);
  for (final fullScreen in [false, true]) {
    test(
      'defers ${fullScreen ? 'fullscreen' : 'maximize'} until reveal',
      () async {
        final window = WindowManager.getInstance();
        window.dispose();
        final root = await Directory.systemTemp.createTemp(
          'sentorr-window-test-',
        );
        final calls = <MethodCall>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const plugin = MethodChannel('window_manager');
        const startup = MethodChannel('sentorr/startup');
        messenger.setMockMethodCallHandler(plugin, (call) async {
          calls.add(call);
          if (call.method == 'getBounds') {
            return {'x': 0.0, 'y': 0.0, 'width': 1100.0, 'height': 760.0};
          }
          return call.method.startsWith('is') ? false : null;
        });
        const screens = MethodChannel(
          'dev.leanflutter.plugins/screen_retriever',
        );
        const display = {
          'id': 'main',
          'size': {'width': 1920.0, 'height': 1080.0},
          'visiblePosition': {'dx': 0.0, 'dy': 0.0},
        };
        messenger.setMockMethodCallHandler(
          screens,
          (call) async => switch (call.method) {
            'getPrimaryDisplay' => display,
            'getAllDisplays' => {
              'displays': [display],
            },
            'getCursorScreenPoint' => {'dx': 0.0, 'dy': 0.0},
            _ => null,
          },
        );
        messenger.setMockMethodCallHandler(startup, (call) async => true);
        addTearDown(() async {
          window.dispose();
          messenger.setMockMethodCallHandler(plugin, null);
          messenger.setMockMethodCallHandler(startup, null);
          messenger.setMockMethodCallHandler(screens, null);
          await root.delete(recursive: true);
        });
        await window.init(
          WindowPreferences(
            startFullScreen: fullScreen,
            startMaximized: !fullScreen,
          ),
          WindowStateRepository(
            store: JsonFileStore(File('${root.path}/window.json')),
          ),
        );
        expect(
          calls.map((call) => call.method),
          isNot(contains('setFullScreen')),
        );
        expect(calls.map((call) => call.method), isNot(contains('maximize')));
        expect(calls.map((call) => call.method), isNot(contains('show')));
        calls.clear();
        await window.reveal();
        expect(calls.first.method, 'ensureInitialized');
        expect(calls[1].method, 'setFullScreen');
        expect(calls[1].arguments, {'isFullScreen': fullScreen});
        expect(
          calls.map((call) => call.method).contains('maximize'),
          !fullScreen,
        );
        expect(calls.map((call) => call.method), contains('show'));
      },
      skip: !supportsWindowCustomization,
    );
  }
}
