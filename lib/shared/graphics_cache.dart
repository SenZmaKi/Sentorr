import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

/// Bounds reusable Skia resources; live surfaces/textures are additional.
/// macOS uses Skia/Metal (see Runner/Info.plist). Other renderers keep defaults.
const macosGraphicsCacheBytes = 32 * 1024 * 1024;

Future<void> configureGraphicsCache() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
  try {
    await SystemChannels.skia.invokeMethod<bool>(
      'Skia.setResourceCacheMaxBytes',
      macosGraphicsCacheBytes,
    );
  } on MissingPluginException {
    // No native rasterizer in framework-only test environments.
  } on PlatformException catch (error) {
    Logger('sentorr.graphics')
        .warning('Could not set graphics cache budget', error);
  }
}
