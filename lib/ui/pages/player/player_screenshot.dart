import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import '../../../player/session.dart';
import 'player_ui.dart';

/// Shared capture flow for the menu and keyboard, with one save at a time.
class PlayerScreenshot {
  PlayerScreenshot(this.player, this.session, this.ui);

  final Player player;
  final PlayerSessionNotifier session;
  final PlayerUi ui;
  bool _saving = false;

  Future<void> capture(bool Function() isActive) async {
    if (_saving) return;
    _saving = true;
    try {
      // Capture before the native dialog opens: playback may continue behind it.
      final bytes = await player.screenshot(format: 'image/png');
      if (!isActive()) return;
      if (bytes == null || bytes.isEmpty) {
        _feedback('No video frame available', Icons.info_outline_rounded);
        return;
      }
      final position = player.state.position.inSeconds;
      final title = session.queue?.current.label ?? 'Sentorr';
      final safeTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final downloads = await _downloadsPath();
      if (!isActive()) return;
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save screenshot',
        initialDirectory: downloads,
        fileName: '$safeTitle-${position}s-$stamp.png',
        type: FileType.custom,
        allowedExtensions: const ['png'],
        bytes: bytes,
      );
      if (path == null) return;
      // Mobile pickers write the bytes; desktop pickers only return a path.
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await File(path).writeAsBytes(bytes, flush: true);
      }
      if (isActive()) _feedback('Screenshot saved', Icons.check_rounded);
    } catch (_) {
      if (isActive()) {
        _feedback('Could not save screenshot', Icons.error_outline_rounded);
      }
    } finally {
      _saving = false;
    }
  }

  Future<String?> _downloadsPath() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return null;
    }
    try {
      final directory = await getDownloadsDirectory();
      if (directory == null || !await directory.exists()) return null;
      return await directory.resolveSymbolicLinks();
    } catch (_) {
      // Keep saving available if the system folder cannot be resolved.
      return null;
    }
  }

  void _feedback(String message, IconData icon) {
    ui.closePanel();
    ui.flash(PlayerFeedback(icon, label: message));
  }
}
