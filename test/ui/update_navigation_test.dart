import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/updates/controller.dart';
import 'package:sentorr/updates/models.dart';
import 'package:sentorr/ui/components/update_navigation_action.dart';
import 'package:sentorr/ui/pages/settings/settings_category.dart';
import 'package:sentorr/ui/pages/settings/settings_page.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

class _Updates extends UpdateController {
  @override
  UpdateState build() => const UpdateState(phase: UpdatePhase.ready);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('ready action opens Updates in $brightness', (tester) async {
      final container = ProviderContainer(
        overrides: [updatesProvider.overrideWith(_Updates.new)],
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
      expect(container.read(settingsRequestProvider), SettingsCategory.updates);
    });
  }
}
