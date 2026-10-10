import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Entry point of the foreground service's own isolate. The plugin delivers
/// notification buttons only there, so it relays them to the app.
@pragma('vm:entry-point')
void startDownloadTask() =>
    FlutterForegroundTask.setTaskHandler(DownloadTask());

class DownloadTask extends TaskHandler {
  static const cancelUpdate = 'updates.cancel';
  static const pause = 'downloads.pause';
  static const resume = 'downloads.resume';

  /// Android stopped the service, e.g. after its daily dataSync allowance.
  static const stopped = 'downloads.stopped';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (isTimeout) FlutterForegroundTask.sendDataToMain(stopped);
  }

  @override
  void onNotificationButtonPressed(String id) =>
      FlutterForegroundTask.sendDataToMain(id);
}
