import 'dart:ffi';
import 'dart:io';

import 'package:media_kit/media_kit.dart';

/// Load the desktop runner's actual bundled decoder, without opening a window.
void initializeBundledVideo(String library) {
  final frameworks = File(library).absolute.parent.parent;
  final pending = frameworks
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.endsWith('.framework'))
      .map(
        (d) =>
            '${d.path}/${d.uri.pathSegments.where((s) => s.isNotEmpty).last.replaceAll('.framework', '')}',
      )
      .toList();
  while (pending.isNotEmpty) {
    final before = pending.length;
    pending.removeWhere((path) {
      try {
        DynamicLibrary.open(path);
        return true;
      } catch (_) {
        return false;
      }
    });
    if (pending.length == before) break;
  }
  MediaKit.ensureInitialized(libmpv: File(library).absolute.path);
}
