import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:tray_manager/tray_manager.dart';

import 'window_manager.dart';

/// Linux may have no tray host: never hide the window there based on icon creation alone.
class DesktopTrayController with TrayListener {
  bool _initialized = false;
  bool _disposed = false;
  Future<void>? _visibilityChange;
  Future<void> _iconChange = Future.value();
  Future<void> Function()? _quit;
  Future<void> Function()? _checkFollowedSeries;
  bool get canHideWindow => _initialized && !Platform.isLinux;
  static const termination = MethodChannel('sentorr/app_termination');
  static const reopen = MethodChannel('sentorr/window_reopen');
  static const menuBarMode = MethodChannel('sentorr/menu_bar_mode');

  Future<void> initialize({
    required Future<void> Function() quit,
    required Future<void> Function() prepareToQuit,
    required Future<void> Function() checkFollowedSeries,
  }) async {
    if (!supportsWindowCustomization || _initialized) return;
    _disposed = false;
    _quit = quit;
    _checkFollowedSeries = checkFollowedSeries;
    configureTerminationHandler(prepareToQuit);
    reopen.setMethodCallHandler((call) async {
      if (call.method != 'restoreWindow') throw MissingPluginException();
      await showWindow();
    });
    try {
      // The native plugin survives hot restart. Reuse its singleton after
      // removing any icon left by the previous Dart isolate.
      await trayManager.destroy();
      trayManager.addListener(this);
      await trayManager.setIcon(_iconAsset('assets/images/tray.png'));
      if (!Platform.isLinux) await trayManager.setToolTip('Sentorr');
      _initialized = true;
      await _refreshMenu();
      WindowManager.getInstance().visible.addListener(_refreshVisibilityLabel);
    } catch (error, stack) {
      Logger('sentorr.tray').warning('Tray disabled', error, stack);
      await dispose();
    }
  }

  /// Native termination asks for cleanup and approval, never another quit.
  static void configureTerminationHandler(
    Future<void> Function() prepareToQuit,
  ) {
    termination.setMethodCallHandler((call) async {
      if (call.method != 'requestQuit') throw MissingPluginException();
      await prepareToQuit();
      return true;
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_disposed) return;
    try {
      await action();
    } catch (error, stack) {
      Logger('sentorr.tray').warning('Tray action failed', error, stack);
    }
  }

  void _refreshVisibilityLabel() => unawaited(_runAction(_refreshMenu));

  Future<void> _refreshMenu() async {
    if (!_initialized || _disposed) return;
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'visibility',
            label: WindowManager.getInstance().visible.value && canHideWindow
                ? 'Hide'
                : 'Show',
          ),
          MenuItem(key: 'check', label: 'Check followed series'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() => unawaited(_runAction(toggleWindowVisibility));

  @override
  void onTrayIconRightMouseDown() => unawaited(
    _runAction(() async {
      await _refreshMenu();
      if (!_disposed) await trayManager.popUpContextMenu();
    }),
  );

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final action = switch (menuItem.key) {
      'visibility' => toggleWindowVisibility,
      'check' => _checkFollowedSeries,
      'quit' => _quit,
      _ => null,
    };
    if (action != null) unawaited(_runAction(action));
  }

  Future<void> toggleWindowVisibility() => _visibilityChange ??=
      (WindowManager.getInstance().visible.value && canHideWindow
              ? hideWindow()
              : showWindow())
          .whenComplete(() => _visibilityChange = null);

  Future<void> showWindow() async {
    if (_disposed) return;
    await _setMenuBarMode(false);
    await WindowManager.getInstance().focus();
  }

  Future<void> hideWindow() async {
    if (_disposed || !canHideWindow) return;
    await WindowManager.getInstance().hide();
    await _setMenuBarMode(true);
  }

  Future<void> _setMenuBarMode(bool enabled) async {
    if (!Platform.isMacOS) return;
    await menuBarMode.invokeMethod<bool>('setEnabled', {'enabled': enabled});
  }

  // The 0.5.x Windows plugin loads ICO files; reuse the existing themed icons.
  String _iconAsset(String asset) => Platform.isWindows
      ? 'assets/images/window-${asset.contains('light') ? 'light' : 'dark'}.ico'
      : asset;

  Future<void> updateIcon(String asset) =>
      _iconChange = _iconChange.catchError((Object _) {}).then((_) async {
        if (_initialized && !_disposed) {
          await trayManager.setIcon(_iconAsset(asset));
        }
      });

  Future<void> dispose() async {
    if (_disposed || !supportsWindowCustomization) return;
    _disposed = true;
    _initialized = false;
    WindowManager.getInstance().visible.removeListener(_refreshVisibilityLabel);
    trayManager.removeListener(this);
    await _iconChange.catchError((Object _) {});
    await trayManager.destroy();
  }
}
