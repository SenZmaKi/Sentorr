import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'backup_bundle.dart';
import 'watch_backup.dart';

/// Saving and loading a backup as a file the viewer chooses.
abstract final class FileBackup {
  static const fileName = 'sentorr-backup.json';

  /// False when the viewer cancelled.
  static Future<bool> export(BackupBundle bundle) async {
    final bytes = utf8.encode(bundle.encode());
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      // Phones write the file themselves; desktops only name it.
      bytes: bytes,
    );
    if (path == null) return false;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return true;
  }

  /// Null when the viewer cancelled; throws [BackupException] when the
  /// file is not a backup.
  static Future<BackupBundle?> import() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a Sentorr backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null) return null;
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) throw const BackupException('Could not read that file.');
    try {
      return BackupBundle.decode(utf8.decode(bytes));
    } on FormatException {
      throw const BackupException('That file is not a Sentorr backup.');
    }
  }
}
