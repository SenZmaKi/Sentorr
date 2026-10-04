import 'dart:async';

import 'package:flutter/services.dart';

import 'picture_in_picture.dart';

/// Android's system Picture-in-Picture, through `PipController.kt`. The OS
/// owns the floating window, its dragging and its transport buttons.
class AndroidPip implements PictureInPicture {
  AndroidPip._() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'changed':
          _changes.add(call.arguments as bool);
        case 'action':
          final action = PipAction.values.asNameMap()[call.arguments];
          if (action != null) _actions.add(action);
      }
    });
  }
  static final instance = AndroidPip._();

  final _channel = const MethodChannel('sentorr/pip');
  final _changes = StreamController<bool>.broadcast();
  final _actions = StreamController<PipAction>.broadcast();

  @override
  bool get supported => true;

  @override
  bool get systemControls => true;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Stream<PipAction> get actions => _actions.stream;

  @override
  Future<bool> enter() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') == true &&
          await _channel.invokeMethod<bool>('enter') == true;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> exit() async {}

  @override
  Future<void> sync(PipControls? controls) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'enabled': controls?.playing ?? false,
        'playing': controls?.playing ?? false,
        'hasNext': controls?.hasNext ?? false,
      });
    } on PlatformException {
      // The window just keeps its previous controls.
    }
  }
}
