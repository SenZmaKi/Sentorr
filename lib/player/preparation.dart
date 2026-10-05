import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../torrents/engine.dart';
import '../torrents/providers.dart';
import 'stream/prepared_stream.dart';
import 'stream/session_config.dart';

final preparedStreamsProvider = Provider<PreparedStreams>((ref) {
  final prepared = PreparedStreams(
    create: (item, candidate) => PendingStream(
      item: item,
      candidate: candidate,
      engine: ref.read(torrentEngineProvider),
      configFor: (release) => sessionConfigFor(ref, release),
      fetchMetadata: (release, cancel) =>
          ref.read(torrentMetadataProvider).fetch(release, cancel),
    ),
  );
  ref.onDispose(prepared.clear);
  return prepared;
});
