import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import 'repository.dart';
import 'resolver.dart';

final torrentRepositoryProvider = Provider<TorrentRepository>(
  (ref) => TorrentRepository.defaults(ref.watch(networkClientProvider).dio),
);

final torrentResolverProvider = Provider<TorrentResolver>(
  (ref) => TorrentResolver(ref.watch(torrentRepositoryProvider)),
);
