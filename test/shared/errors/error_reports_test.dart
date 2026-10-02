import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:sentorr/shared/errors/error_reports.dart';
import 'package:sentorr/shared/log.dart';

void main() {
  setUpAll(setupLogger);

  test('delivers a report raised before anyone listens', () async {
    ErrorReports.report('Early failure', StateError('boot'));
    final report = await ErrorReports.stream.first;
    expect(report.title, 'Early failure');
    expect(report.message, 'Bad state: boot');
  });

  test('shows a repeated failure once per window', () async {
    final seen = <ErrorReport>[];
    final subscription = ErrorReports.stream.listen(seen.add);
    for (var i = 0; i < 3; i++) {
      ErrorReports.report('Layout failure', Exception('overflow'));
    }
    ErrorReports.report('Layout failure', Exception('another'));
    await pumpEventQueue();
    await subscription.cancel();
    expect(seen.map((r) => r.message), ['overflow', 'another']);
  });

  test('details carry the stack and what was logged before', () async {
    Logger('sentorr.test').info('Searched "Dune 2021"');
    final stack = StackTrace.current;
    final reports = ErrorReports.stream.first;
    ErrorReports.report('Search failed', const FormatException('bad'), stack);
    final details = (await reports).details;
    expect(details, contains('Error: FormatException: bad'));
    expect(details, contains('Stack trace:'));
    expect(details, contains('Searched "Dune 2021"'));
  });
}
