import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/net/online.dart';
import '../../components/cards/card_skeleton.dart';
import '../../components/load_error.dart';
import '../../components/shelf.dart';
import '../../shared/theme/theme.dart';
import 'home_layout.dart';

/// A home row driven by an async list: skeletons while loading, an inline
/// retry on failure, and nothing at all when there is nothing to show.
/// Offline, a failed row steps aside: the offline notice explains it and
/// the row reloads once the connection is back.
class AsyncShelf<T> extends ConsumerWidget {
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
    this.action,
    this.gutter,
    this.top = Space.s40,
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

  /// Trailing control in the row's header, e.g. "See all".
  final Widget? action;

  /// Overrides the page's side inset, e.g. inside a narrower column.
  final double? gutter;

  /// Space above the row.
  final double top;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.hasError && !items.hasValue && !ref.watch(onlineProvider)) {
      return const SizedBox.shrink();
    }
    final layout = HomeLayout.of(context);
    final gutter = this.gutter ?? layout.insets.side;
    Shelf shelf({
      int length = 0,
      IndexedWidgetBuilder? builder,
      Widget? message,
    }) => Shelf(
      icon: icon,
      title: title,
      subtitle: subtitle,
      count: length > 0 ? count?.call(length) : null,
      gutter: gutter,
      tileWidth: spec.width,
      tileHeight: spec.height,
      artworkHeight: spec.artworkHeight,
      itemCount: length,
      itemBuilder: builder ?? (_, _) => const SizedBox.shrink(),
      message: message,
      action: action,
    );
    final content = items.when(
      data: (list) => list.isEmpty
          ? null
          : shelf(
              length: list.length,
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
        gutter: gutter,
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
      padding: EdgeInsets.only(top: top),
      child: content,
    );
  }
}
