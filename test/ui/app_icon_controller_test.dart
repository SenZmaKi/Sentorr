import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/shared/app_icon_controller.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const window = MethodChannel('window_manager');
  const appearance = MethodChannel('sentorr/app_icon');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    for (final channel in [window, appearance]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
    }
  });
  tearDown(() {
    for (final channel in [window, appearance]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    test('$platform applies chrome and icon before update completes', () async {
      final icons = AppIconController(platform: platform);
      for (final brand in [SentorrBrand.light, SentorrBrand.dark]) {
        calls.clear();
        await icons.update(brand);
        expect(calls.map((call) => call.method), [
          'setBrightness',
          'setBackgroundColor',
          'setIcon',
        ]);
        expect(
          calls.first.arguments,
          platform == TargetPlatform.windows
              ? brand.brightness.name
              : {'brightness': brand.brightness.name},
        );
        final background = calls[1].arguments as Map;
        final colors = brand == SentorrBrand.light
            ? SentorrColors.light
            : SentorrColors.dark;
        expect(background['backgroundColorR'], (colors.canvas.r * 255).round());
        final path = (calls.last.arguments as Map)['iconPath'] as String;
        expect(
          path,
          endsWith(
            platform == TargetPlatform.windows ? brand.window : brand.dock,
          ),
        );
      }
    });
  }

  test('Android persists every mode, including returning to system', () async {
    final icons = AppIconController(platform: TargetPlatform.android);
    for (final mode in ThemeMode.values) {
      await icons.updateSplash(mode);
    }
    expect(calls.map((call) => call.method).toSet(), {'setSplashTheme'});
    expect(calls.map((call) => call.arguments), ['system', 'light', 'dark']);
  });

  test('explicit theme overrides the system brightness at startup', () {
    for (final brightness in Brightness.values) {
      expect(
        SentorrBrand.resolve(ThemeMode.light, brightness),
        SentorrBrand.light,
      );
      expect(
        SentorrBrand.resolve(ThemeMode.dark, brightness),
        SentorrBrand.dark,
      );
      expect(
        SentorrBrand.resolve(ThemeMode.system, brightness).brightness,
        brightness,
      );
    }
  });
}
