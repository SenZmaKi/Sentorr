import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import 'models.dart';

/// Shared by every screen that needs one title's details, so a hero,
/// a backdrop and series metadata reuse one request.
final titleDetailsProvider = FutureProvider.family<ImdbTitleDetails, String>((
  ref,
  id,
) {
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref
      .watch(imdbRepositoryProvider)
      .getTitleDetails(id, previewLimit: 20, cancelToken: cancel);
});
