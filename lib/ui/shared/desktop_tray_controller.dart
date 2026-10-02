import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:tray_manager/tray_manager.dart';

import 'window_manager.dart';

/// Linux may have no tray host: never hide the window there based on icon creation alone.
class DesktopTrayController {
  TrayIcon? _icon;
  Menu? _menu;
  Image? _image;
  final _items = <MenuItem>[];
  bool get canHideWindow => _icon != null && !Platform.isLinux;
  static const termination = MethodChannel('sentorr/app_termination');
  static const reopen = MethodChannel('sentorr/window_reopen');

  Future<void> initialize({
    required Future<void> Function() quit,
    required Future<void> Function() prepareToQuit,
  }) async {
    if (!supportsWindowCustomization) return;
    configureTerminationHandler(prepareToQuit);
    reopen.setMethodCallHandler((call) async {
      if (call.method != 'restoreWindow') throw MissingPluginException();
      await WindowManager.getInstance().focus();
    });
    try {
      _icon = TrayIcon.create();
      _menu = Menu.create();
      _image = ImageAsset.fromAsset('assets/images/tray.png');
      if (_icon == null || _menu == null || _image == null) {
        throw StateError('Tray resources unavailable');
      }
      _icon!.icon = _image;
      _icon!.setTooltip('Sentorr');
      _addItem('Show', WindowManager.getInstance().focus);
      if (!Platform.isLinux) _addItem('Hide', WindowManager.getInstance().hide);
      _menu!.addSeparator();
      _addItem('Quit', quit);
      _icon!.setContextMenu(_menu!);
      if (!_icon!.setVisible(true)) throw StateError('Tray unavailable');
    } catch (error, stack) {
      Logger('sentorr.tray').warning('Tray disabled', error, stack);
      dispose();
    }
  }

  /// Native termination asks for cleanup and approval, never another quit.
  static void configureTerminationHandler(
    Future<void> Function() prepareToQuit,
  ) {
    termination.setMethodCallHandler((call) async {
      if (call.method != 'requestQuit') throw MissingPluginException();
      // macOS is already terminating. Calling quit here would request native
      // termination again and wait on the approval we are currently handling.
      await prepareToQuit();
      return true;
    });
  }

  void _addItem(String label, Future<void> Function() action) {
    final item = MenuItem.createWithLabelAndType(label, MenuItemType.normal);
    if (item == null) throw StateError('Tray menu unavailable');
    _items.add(item);
    item.addListener((event) {
      if (event is MenuItemClickedEvent) unawaited(action());
    });
    _menu!.addItem(item);
  }

  void updateIcon(String asset) {
    if (_icon == null) return;
    final image = ImageAsset.fromAsset(asset);
    if (image == null) throw StateError('Tray icon unavailable: $asset');
    _icon!.icon = image;
    _image?.dispose();
    _image = image;
  }

  void dispose() {
    _icon?.setVisible(false);
    _icon?.dispose();
    _icon = null;
    _menu?.dispose();
    _menu = null;
    for (final item in _items) {
      item.dispose();
    }
    _items.clear();
    _image?.dispose();
    _image = null;
  }
}
