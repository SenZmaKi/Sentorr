import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import 'repository.dart';

final torrentRepositoryProvider = Provider<TorrentRepository>(
  (ref) => TorrentRepository.defaults(ref.watch(networkClientProvider).dio),
);
