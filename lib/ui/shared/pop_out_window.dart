import 'package:flutter/painting.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'window_manager.dart' as app;

/// Turns the app window into a small, always-on-top, frameless video window
/// in the screen's corner, and back. The player keeps playing throughout:
/// it is the same window and the same player, only resized.
class PopOutWindow {
  PopOutWindow._();
  static final instance = PopOutWindow._();

  static const _size = Size(480, 270);
  static const _margin = 24.0;

  Rect? _restore;
  bool _wasMaximized = false;
  bool _wasOnTop = false;
  bool _active = false;

  bool get supported => app.supportsWindowCustomization;

  Future<void> enter() async {
    if (!supported || _active) return;
    _active = true;
    app.WindowManager.getInstance().suspendBoundsSaving = true;
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
    }
    _wasMaximized = await windowManager.isMaximized();
    if (_wasMaximized) await windowManager.unmaximize();
    _restore = await windowManager.getBounds();
    _wasOnTop = await windowManager.isAlwaysOnTop();
    final display = await _displayFor(_restore!);
    final frame = Rect.fromLTWH(
      display.visiblePosition?.dx ?? 0,
      display.visiblePosition?.dy ?? 0,
      (display.visibleSize ?? display.size).width,
      (display.visibleSize ?? display.size).height,
    );
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setMinimumSize(const Size(256, 144));
    await windowManager.setBounds(
      Rect.fromLTWH(
        frame.right - _size.width - _margin,
        frame.bottom - _size.height - _margin,
        _size.width,
        _size.height,
      ),
      animate: true,
    );
    await windowManager.setAspectRatio(16 / 9);
    await windowManager.setAlwaysOnTop(true);
  }

  Future<void> exit() async {
    if (!supported || !_active) return;
    _active = false;
    await windowManager.setAspectRatio(0);
    await windowManager.setAlwaysOnTop(_wasOnTop);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setMinimumSize(app.minimumWindowSize);
    final restore = _restore;
    if (restore != null) await windowManager.setBounds(restore, animate: true);
    if (_wasMaximized) await windowManager.maximize();
    app.WindowManager.getInstance().suspendBoundsSaving = false;
  }

  /// Moves the frameless window with the pointer.
  Future<void> startDragging() => windowManager.startDragging();

  Future<Display> _displayFor(Rect bounds) async {
    final displays = await screenRetriever.getAllDisplays();
    final center = bounds.center;
    for (final d in displays) {
      final p = d.visiblePosition ?? Offset.zero;
      final s = d.visibleSize ?? d.size;
      if (Rect.fromLTWH(p.dx, p.dy, s.width, s.height).contains(center)) {
        return d;
      }
    }
    return screenRetriever.getPrimaryDisplay();
  }
}
