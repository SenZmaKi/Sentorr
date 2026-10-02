import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/shared/errors/error_reports.dart';
import 'package:sentorr/ui/components/error_toasts.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  testWidgets('shows a report, copies its details and closes itself', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        builder: (context, child) => ErrorToasts(child: child!),
        home: const SizedBox.shrink(),
      ),
    );

    ErrorReports.report('Playback failed', StateError('decoder'));
    await tester.pumpAndSettle();
    expect(find.text('Playback failed'), findsOneWidget);
    expect(find.text('Bad state: decoder'), findsOneWidget);

    await tester.tap(find.text('Copy details'));
    await tester.pump();
    expect(copied, contains('Error: Bad state: decoder'));
    expect(find.text('Copied'), findsOneWidget);

    await tester.pump(ErrorToasts.lifetime);
    await tester.pumpAndSettle();
    expect(find.text('Playback failed'), findsNothing);
  });
}
