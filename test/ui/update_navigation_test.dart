import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/updates/controller.dart';
import 'package:sentorr/updates/models.dart';
import 'package:sentorr/updates/platform_installer.dart';
import 'package:sentorr/ui/components/update_navigation_action.dart';
import 'package:sentorr/ui/pages/settings/settings_page.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

class _Updates extends UpdateController {
  static int installs = 0;

  @override
  UpdateState build() => const UpdateState(phase: UpdatePhase.ready);

  @override
  Future<UpdateInstallDisposition?> installAndRestart() async {
    installs++;
    return UpdateInstallDisposition.externalInstallerOpened;
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('ready action installs in $brightness', (tester) async {
      _Updates.installs = 0;
      var prepared = 0;
      final container = ProviderContainer(
        overrides: [
          updatesProvider.overrideWith(_Updates.new),
          prepareForUpdateProvider.overrideWithValue(() async => prepared++),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildSentorrTheme(brightness),
            home: const Scaffold(body: UpdateNavigationAction()),
          ),
        ),
      );
      await tester.tap(find.text('Update ready'));
      await tester.pump();
      expect(prepared, 1);
      expect(_Updates.installs, 1);
      expect(container.read(settingsRequestProvider), isNull);
    });
  }
}
