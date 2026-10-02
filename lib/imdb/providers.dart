import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import 'models.dart';

/// Shared by every screen that needs one title's details, so a hero,
/// a backdrop and series metadata reuse one request.
final titleDetailsProvider = FutureProvider.autoDispose
    .family<ImdbTitleDetails, String>((ref, id) async {
      final cancel = CancelToken();
      // Queue builders also read .future without a widget listener. Keep that
      // request alive, then release unused details when their listeners leave;
      // the HTTP disk cache can satisfy a later visit.
      final keep = ref.keepAlive();
      ref.onDispose(() {
        cancel.cancel();
      });
      try {
        final details = await ref
            .watch(imdbRepositoryProvider)
            .getTitleDetails(id, previewLimit: 20, cancelToken: cancel);
        if (ref.mounted) keep.close();
        return details;
      } catch (_) {
        keep.close();
        rethrow;
      }
    });

/// A title's reviews, best regarded first; [spoilers] includes reviews that
/// reveal the plot.
final titleReviewsProvider =
    FutureProvider.family<List<ImdbReview>, ({String id, bool spoilers})>((
      ref,
      key,
    ) async {
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      final page = await ref
          .watch(imdbRepositoryProvider)
          .getReviews(
            key.id,
            limit: 12,
            hideSpoilers: !key.spoilers,
            cancelToken: cancel,
          );
      return page.items;
    });
