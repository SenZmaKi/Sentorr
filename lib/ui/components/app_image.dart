import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/services.dart';
import '../shared/theme/theme.dart';
import 'motion.dart';

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
  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    label: semanticLabel,
    image: true,
    child: CachedNetworkImage(
      imageUrl: url,
      cacheManager: ref.watch(imageCacheProvider),
      memCacheWidth: decodeWidth,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      fadeInDuration: reduceMotion(context) ? Duration.zero : Motion.panel,
      fadeOutDuration: reduceMotion(context) ? Duration.zero : Motion.panel,
      placeholder: (_, _) =>
          placeholder ? const ArtworkPlaceholder() : const SizedBox.shrink(),
      errorWidget: (_, _, _) => placeholder
          ? const ArtworkPlaceholder(icon: Icons.broken_image_outlined)
          : const SizedBox.shrink(),
    ),
  );
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
