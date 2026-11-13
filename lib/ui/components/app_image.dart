import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/services.dart';
import '../../shared/net/online.dart';
import '../shared/theme/theme.dart';
import 'motion.dart';
import 'skeleton.dart';

/// Catalog artwork shares the app's disk cache on every supported platform.
class AppImage extends ConsumerWidget {
  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.placeholder = true,
    this.decodeWidth,
    this.fallbackUrls = const [],
  });
  final String url;
  final double? width, height;
  final BoxFit fit;
  final Alignment alignment;
  final String? semanticLabel;

  /// Physical pixels needed for a cover fit; bounds decode even if the CDN
  /// ignores its rendition URL or snaps it to a larger size.
  final int? decodeWidth;

  /// Decorative uses (e.g. blurred washes) stay empty instead.
  final bool placeholder;

  /// Other renditions of the same picture, nearest first. When [url] cannot
  /// be fetched, as offline, whichever of these is on disk shows instead.
  final List<String> fallbackUrls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(imageCacheProvider);
    // Artwork that failed offline tries again once the connection is back.
    final online = ref.watch(onlineProvider);
    final failed = !placeholder
        ? const SizedBox.shrink()
        : ArtworkPlaceholder(
            icon: online ? Icons.broken_image_outlined : Icons.movie_outlined,
          );
    return Semantics(
      label: semanticLabel,
      image: true,
      child: CachedNetworkImage(
        key: ValueKey((url, online)),
        imageUrl: url,
        cacheManager: cache,
        memCacheWidth: decodeWidth,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        fadeInDuration: reduceMotion(context) ? Duration.zero : Motion.panel,
        fadeOutDuration: reduceMotion(context) ? Duration.zero : Motion.panel,
        placeholder: (_, _) => !placeholder
            ? const SizedBox.shrink()
            : const Skeleton(radius: Radii.card),
        errorWidget: (_, _, _) => fallbackUrls.isEmpty
            ? failed
            : _CachedRendition(image: this, cache: cache, orElse: failed),
      ),
    );
  }
}

/// The first of an image's [AppImage.fallbackUrls] already on disk.
class _CachedRendition extends StatefulWidget {
  const _CachedRendition({
    required this.image,
    required this.cache,
    required this.orElse,
  });

  final AppImage image;
  final CacheManager cache;
  final Widget orElse;

  @override
  State<_CachedRendition> createState() => _CachedRenditionState();
}

class _CachedRenditionState extends State<_CachedRendition> {
  late final Future<File?> _file = _find();

  Future<File?> _find() async {
    for (final url in widget.image.fallbackUrls) {
      final cached = await widget.cache.getFileFromCache(url);
      if (cached != null) return cached.file;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    return FutureBuilder(
      future: _file,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return snapshot.connectionState == ConnectionState.done
              ? widget.orElse
              : const SizedBox.shrink();
        }
        return Image.file(
          file,
          cacheWidth: image.decodeWidth,
          width: image.width,
          height: image.height,
          fit: image.fit,
          alignment: image.alignment,
          errorBuilder: (_, _, _) => widget.orElse,
        );
      },
    );
  }
}

/// Neutral stand-in while artwork loads or when a title has none.
class ArtworkPlaceholder extends StatelessWidget {
  const ArtworkPlaceholder({super.key, this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceControl,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: icon == null
          ? const SizedBox.expand()
          : Center(
              child: Icon(
                icon,
                size: IconSizes.navigation,
                color: c.foregroundMuted,
              ),
            ),
    );
  }
}
