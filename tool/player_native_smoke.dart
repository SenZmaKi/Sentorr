// Native rendering regression check (macOS):
// python3 -m http.server 18767 --bind 127.0.0.1 \
//   --directory tool/codec_lab/assets/media
// flutter run -d macos -t tool/player_native_smoke.dart
// Override the fixture with --dart-define=SMOKE_MEDIA=http://...
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sentorr/app/bootstrap.dart';

Future<void> main() async {
  await AppRuntime.initialize();
  final player = Player();
  player.stream.error.listen((error) => print('NATIVE_SMOKE_ERROR: $error'));
  final video = VideoController(player);
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Video(controller: video, controls: NoVideoControls),
      ),
    ),
  );
  await video.platform.future.timeout(const Duration(seconds: 20));
  final images = _mpvImages();
  if (images.length != 1) {
    print('NATIVE_SMOKE_FAIL: expected one mpv image, found $images');
    exit(1);
  }
  await player.open(
    Media(
      const String.fromEnvironment(
        'SMOKE_MEDIA',
        defaultValue: 'http://127.0.0.1:18767/bbb_h264.mp4',
      ),
    ),
  );
  await player.stream.position
      .firstWhere((p) => p.inSeconds >= 2)
      .timeout(const Duration(seconds: 20));
  final width = player.state.width ?? 0;
  print(
    'NATIVE_SMOKE: mpv=$images position=${player.state.position} width=$width',
  );
  exit(width > 0 ? 0 : 1);
}

// Detect the duplicate-image condition from the user's macOS crash reports.
List<String> _mpvImages() {
  final native = DynamicLibrary.process();
  final count = native.lookupFunction<Uint32 Function(), int Function()>(
    '_dyld_image_count',
  );
  final name = native
      .lookupFunction<
        Pointer<Uint8> Function(Uint32),
        Pointer<Uint8> Function(int)
      >('_dyld_get_image_name');
  return [
    for (var i = 0; i < count(); i++)
      if (_string(name(i)).contains('/Mpv.framework/')) _string(name(i)),
  ];
}

String _string(Pointer<Uint8> pointer) {
  var length = 0;
  while (pointer[length] != 0) {
    length++;
  }
  return utf8.decode(pointer.asTypedList(length));
}
