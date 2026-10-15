import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import 'menu_rows.dart';
import 'player_actions.dart';
import 'player_ui.dart';

/// Captures the decoded picture, excluding Flutter controls and overlays.
class ScreenshotAction extends StatefulWidget {
  const ScreenshotAction({
    super.key,
    required this.player,
    required this.actions,
  });

  final Player player;
  final PlayerActions actions;

  @override
  State<ScreenshotAction> createState() => _ScreenshotActionState();
}

class _ScreenshotActionState extends State<ScreenshotAction> {
  bool _saving = false;

  Future<void> _capture() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // Capture before the native dialog opens: playback may continue behind it.
      final bytes = await widget.player.screenshot(format: 'image/png');
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        _feedback('No video frame available', Icons.info_outline_rounded);
        return;
      }
      final position = widget.player.state.position.inSeconds;
      final title = widget.actions.session.queue?.current.label ?? 'Sentorr';
      final safeTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final downloads = await _downloadsPath();
      if (!mounted) return;
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
      if (mounted) _feedback('Screenshot saved', Icons.check_rounded);
    } catch (_) {
      if (mounted) {
        _feedback('Could not save screenshot', Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
    widget.actions.ui.closePanel();
    widget.actions.ui.flash(PlayerFeedback(icon, label: message));
  }

  @override
  Widget build(BuildContext context) => PlayerMenuRow(
    icon: Icons.photo_camera_outlined,
    label: 'Take screenshot',
    value: _saving ? 'Saving…' : null,
    onTap: _saving ? null : _capture,
  );
}
