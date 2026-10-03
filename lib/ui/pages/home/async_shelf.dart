import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/cards/card_skeleton.dart';
import '../../components/load_error.dart';
import '../../components/shelf.dart';
import '../../shared/theme/theme.dart';
import 'home_layout.dart';

/// A home row driven by an async list: skeletons while loading, an inline
/// retry on failure, and nothing at all when there is nothing to show.
class AsyncShelf<T> extends StatelessWidget {
  const AsyncShelf({
    super.key,
    required this.icon,
    required this.title,
    required this.items,
    required this.spec,
    required this.cardBuilder,
    required this.onRetry,
    this.subtitle,
    this.count,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Optional tally for the header once items arrive, e.g. "5 new".
  final String Function(int length)? count;
  final AsyncValue<List<T>> items;
  final CardSpec spec;
  final Widget Function(BuildContext context, T item, int index) cardBuilder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final layout = HomeLayout.of(context);
    Shelf shelf({
      int length = 0,
      bool reveal = false,
      IndexedWidgetBuilder? builder,
      Widget? message,
    }) => Shelf(
      icon: icon,
      title: title,
      subtitle: subtitle,
      count: length > 0 ? count?.call(length) : null,
      gutter: layout.insets.side,
      tileWidth: spec.width,
      tileHeight: spec.height,
      artworkHeight: spec.artworkHeight,
      itemCount: length,
      itemBuilder: builder ?? (_, _) => const SizedBox.shrink(),
      message: message,
      reveal: reveal,
    );
    final content = items.when(
      data: (list) => list.isEmpty
          ? null
          : shelf(
              length: list.length,
              reveal: true,
              builder: (context, i) => cardBuilder(context, list[i], i),
            ),
      error: (_, _) => shelf(
        message: Align(
          alignment: Alignment.centerLeft,
          child: LoadError(
            message:
                "Couldn't load ${title.toLowerCase()}. Check your connection.",
            onRetry: onRetry,
          ),
        ),
      ),
      loading: () => Shelf(
        icon: icon,
        title: title,
        subtitle: subtitle,
        gutter: layout.insets.side,
        tileWidth: spec.width,
        tileHeight: spec.height,
        artworkHeight: spec.artworkHeight,
        itemCount: 8,
        itemBuilder: (_, _) => Align(
          alignment: Alignment.topRight,
          child: SizedBox(
            width: spec.artworkWidth,
            child: CardSkeleton(
              aspectRatio: spec.artworkWidth / spec.artworkHeight,
            ),
          ),
        ),
      ),
    );
    if (content == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Space.s40),
      child: content,
    );
  }
}
