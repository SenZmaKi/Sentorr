import 'dart:io';

import 'package:logging/logging.dart';

/// Shows [path] in the platform's file manager, creating it if needed.
Future<void> openFolder(String path) async {
  try {
    await Directory(path).create(recursive: true);
    final command = Platform.isMacOS
        ? 'open'
        : Platform.isWindows
        ? 'explorer'
        : 'xdg-open';
    await Process.run(command, [path]);
  } catch (error, stack) {
    Logger('sentorr.ui').warning('Could not open $path', error, stack);
  }
}
