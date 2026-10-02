import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/services.dart';

/// Catalog artwork shares the app's disk cache on every supported platform.
class AppImage extends ConsumerWidget {
  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });
  final String url;
  final double? width, height;
  final BoxFit fit;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    label: semanticLabel,
    image: true,
    child: CachedNetworkImage(
      imageUrl: url,
      cacheManager: ref.watch(imageCacheProvider),
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
      errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
    ),
  );
}
