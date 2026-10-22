import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/startup.dart';

void main() {
  testWidgets(
    'an early startup failure is visible and Retry initializes again',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('window_manager');
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method.startsWith('is') ? false : null,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      var attempts = 0;
      await tester.pumpWidget(
        AppStartup(
          initialize: () async {
            attempts++;
            throw StateError('temporary initialization failure');
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sentorr could not start'), findsOneWidget);
      expect(attempts, 1);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Sentorr could not start'), findsOneWidget);
    },
  );
}
