import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/sync/pairing.dart';
import 'package:sentorr/ui/pages/settings/sections/pairing_sheet.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_sync.dart';

/// Already paired with a laptop.
class _Paired extends PairingNotifier {
  @override
  PairingState build() => const PairingDone('Laptop');
}

void main() {
  testWidgets('closing after pairing keeps the result until it is gone', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ...syncOverrides(),
        pairingProvider.overrideWith(_Paired.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildSentorrTheme(Brightness.dark),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showPairingSheet(context, ref),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Paired with Laptop'), findsOneWidget);

    await tester.tap(find.text('Done'));
    // Mid-way through the sheet's exit.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Pair a device'), findsNothing);
    }
    expect(container.read(pairingProvider), isA<PairingIdle>());
    await tester.pumpAndSettle();
    expect(find.text('Paired with Laptop'), findsNothing);
  });
}
