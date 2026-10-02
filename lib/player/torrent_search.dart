import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/notifier.dart';
import '../torrents/providers.dart';
import '../torrents/resolution_models.dart';
import 'models.dart';
import 'torrent_lookup.dart';

/// Searches the sources for [item] with the viewer's torrent settings,
/// under [title] when the catalog name is not how releases are labelled.
typedef TorrentSearch = Future<TorrentResolution> Function(
  PlaybackItem item, {
  String? title,
  CancelToken? cancel,
});

final torrentSearchProvider = Provider<TorrentSearch>(
  (ref) => (item, {title, cancel}) {
    final settings = ref.read(settingsProvider).torrents;
    return ref
        .read(torrentResolverProvider)
        .resolve(
          torrentQueryFor(item, languages: settings.languages, title: title),
          preferences: torrentPreferencesFor(settings),
          cancelToken: cancel,
        );
  },
);
