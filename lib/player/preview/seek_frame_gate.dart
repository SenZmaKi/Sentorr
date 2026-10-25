import 'dart:ffi';

import 'package:media_kit/generated/libmpv/bindings.dart' as mpv;
import 'package:media_kit/media_kit.dart';

/// A separate event queue: never consumes MediaKit's playback events. Unlike
/// observed properties, SEEK/PLAYBACK_RESTART events are not coalesced away.
class SeekFrameGate {
  SeekFrameGate(this.native) {
    _client = native.mpv.mpv_create_client(native.ctx, nullptr);
    if (_client == nullptr) {
      throw StateError('Cannot watch preview seek events');
    }
  }
  final NativePlayer native;
  late Pointer<mpv.mpv_handle> _client;
  bool _started = false;

  void begin() {
    while (_client != nullptr &&
        native.mpv.mpv_wait_event(_client, 0).ref.event_id !=
            mpv.mpv_event_id.MPV_EVENT_NONE) {}
    _started = false;
  }

  bool get ready {
    while (_client != nullptr) {
      final event = native.mpv.mpv_wait_event(_client, 0).ref.event_id;
      if (event == mpv.mpv_event_id.MPV_EVENT_NONE) return false;
      if (event == mpv.mpv_event_id.MPV_EVENT_SEEK) _started = true;
      if (event == mpv.mpv_event_id.MPV_EVENT_PLAYBACK_RESTART && _started) {
        return true;
      }
    }
    return false;
  }

  void dispose() {
    if (_client == nullptr) return;
    native.mpv.mpv_destroy(_client);
    _client = nullptr;
  }
}
