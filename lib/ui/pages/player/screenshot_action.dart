import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'menu_rows.dart';
import 'player_actions.dart';

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
    setState(() => _saving = true);
    try {
      await widget.actions.takeScreenshot(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PlayerMenuRow(
    icon: Icons.photo_camera_outlined,
    label: 'Take screenshot (Shift S)',
    value: _saving ? 'Saving…' : null,
    onTap: _saving ? null : _capture,
  );
}
