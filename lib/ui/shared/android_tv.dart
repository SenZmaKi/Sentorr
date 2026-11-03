import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native device mode, rather than screen width (a tablet can be just as wide).
Future<bool> detectAndroidTv() async {
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await const MethodChannel('sentorr/device')
            .invokeMethod<bool>('isTv') ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
