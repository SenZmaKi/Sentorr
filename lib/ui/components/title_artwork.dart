import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../imdb/images.dart';
import '../../imdb/models.dart';
import '../../imdb/providers.dart';
import '../shared/theme/theme.dart';
import 'app_image.dart';

/// IMDb artwork fetched at the size it is drawn, not the 2000+ px original.
class TitleArtwork extends StatelessWidget {
  const TitleArtwork({
    super.key,
    required this.image,
    this.alignment = Alignment.center,
  });

  final ImdbImage? image;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (image == null) {
      return const ArtworkPlaceholder(icon: Icons.movie_outlined);
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        // A cover fit scales to whichever side overflows the frame.
        var width = box.maxWidth;
        final w = image.width, h = image.height;
        if (w != null && h != null && box.hasBoundedHeight) {
          final scale = box.maxHeight / h;
          if (w * scale > width) width = w * scale;
        }
        return AppImage(
          url: imdbImageUrl(image.url, width: width * dpr),
          decodeWidth: (width * dpr).clamp(1, 2560).ceil(),
          alignment: alignment,
          width: box.maxWidth,
          height: box.hasBoundedHeight ? box.maxHeight : null,
        );
      },
    );
  }
}

/// Landscape art for a title: its widest still once details arrive, or the
/// poster cropped toward the top (where faces usually are) as a fallback.
class TitleBackdrop extends ConsumerWidget {
  const TitleBackdrop({
    super.key,
    required this.title,
    this.waitForBackdrop = false,
    this.posterFallback = true,
  });

  final ImdbTitle title;

  /// Wait for details (or their failure) before falling back to the poster,
  /// so a poster never shows only to be swapped for a backdrop.
  final bool waitForBackdrop;

  /// Allow a cropped poster when no backdrop is available.
  final bool posterFallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(titleDetailsProvider(title.id));
    final backdrop = details.whenOrNull(data: (d) => d.backdropCandidate);
    return AnimatedSwitcher(
      duration: Motion.panel,
      child: backdrop != null
          ? TitleArtwork(key: ValueKey(backdrop.url), image: backdrop)
          : posterFallback &&
                (!waitForBackdrop || details.hasValue || details.hasError)
          ? TitleArtwork(
              key: const ValueKey('poster'),
              image: title.poster,
              alignment: const Alignment(0, -0.6),
            )
          : const ArtworkPlaceholder(),
    );
  }
}
