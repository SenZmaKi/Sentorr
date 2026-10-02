import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../watching/models.dart';
import '../watching/notifier.dart';

/// Movies and series the viewer is partway through, newest first.
final continueWatchingProvider = Provider<AsyncValue<List<WatchEntry>>>(
  (ref) => AsyncData(ref.watch(inProgressProvider)),
);
