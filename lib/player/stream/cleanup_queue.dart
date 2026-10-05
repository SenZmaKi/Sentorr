import 'package:logging/logging.dart';

final _log = Logger('sentorr.player.stream');

/// Serial cleanup that attempts every resource even when an earlier step fails.
class CleanupQueue {
  Future<void> _pending = Future.value();

  Future<void> get pending => _pending;

  Future<void> run(List<Future<void> Function()> steps) {
    return _pending = _pending.then((_) async {
      for (final step in steps) {
        try {
          await step();
        } catch (error, stack) {
          _log.warning('Playback cleanup failed', error, stack);
        }
      }
    });
  }
}
