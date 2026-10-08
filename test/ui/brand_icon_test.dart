import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/ui/components/app_shell.dart';
import 'package:sentorr/ui/components/app_icon_sync.dart';
import 'package:sentorr/ui/components/side_nav.dart';
import 'package:sentorr/ui/shared/app_icon_controller.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

class RecordingIcons extends AppIconController {
  final variants = <String>[];
  final splashModes = <ThemeMode>[];

  @override
  Future<void> update(SentorrBrand brand) async => variants.add(brand.variant);

  @override
  Future<void> updateSplash(ThemeMode mode) async => splashModes.add(mode);
}

void main() {
  testWidgets('nav and desktop icons follow explicit and system themes live', (
    tester,
  ) async {
    final mode = ValueNotifier(ThemeMode.dark);
    final icons = RecordingIcons();
    addTearDown(mode.dispose);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appIconControllerProvider.overrideWithValue(icons)],
        child: ValueListenableBuilder(
          valueListenable: mode,
          builder: (context, value, child) => MaterialApp(
            theme: buildSentorrTheme(Brightness.light),
            darkTheme: buildSentorrTheme(Brightness.dark),
            themeMode: value,
            builder: (context, child) => AppIconSync(child: child!),
            home: Scaffold(
              body: SideNav(current: AppDestination.home, onSelect: (_) {}),
            ),
          ),
        ),
      ),
    );

    Future<void> expectVariant(SentorrBrand brand) async {
      await tester.pumpAndSettle();
      final logo = tester.widget<Image>(
        find.byWidgetPredicate(
          (w) => w is Image && w.semanticLabel == 'Sentorr',
        ),
      );
      final image = logo.image;
      final asset = image is ResizeImage ? image.imageProvider : image;
      expect((asset as AssetImage).assetName, brand.logo);
      expect(icons.variants.last, brand.variant);
      expect(tester.takeException(), isNull);
    }

    await expectVariant(SentorrBrand.dark);
    mode.value = ThemeMode.light;
    await expectVariant(SentorrBrand.light);
    mode.value = ThemeMode.dark;
    await expectVariant(SentorrBrand.dark);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    mode.value = ThemeMode.system;
    await expectVariant(SentorrBrand.light);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await expectVariant(SentorrBrand.dark);
    expect(icons.variants, ['dark', 'light', 'dark', 'light', 'dark']);
  });

  testWidgets('splash follows the saved theme mode', (tester) async {
    final icons = RecordingIcons();
    Future<void> pumpMode(ThemeMode mode) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appIconControllerProvider.overrideWithValue(icons),
            initialSettingsProvider.overrideWithValue(
              AppSettings(themeMode: mode),
            ),
          ],
          child: MaterialApp(
            theme: buildSentorrTheme(Brightness.dark),
            builder: (context, child) => AppIconSync(child: child!),
            home: const SizedBox(),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpMode(ThemeMode.system);
    await pumpMode(ThemeMode.light);
    await pumpMode(ThemeMode.dark);
    expect(icons.splashModes, [
      ThemeMode.system,
      ThemeMode.light,
      ThemeMode.dark,
    ]);
  });
}
