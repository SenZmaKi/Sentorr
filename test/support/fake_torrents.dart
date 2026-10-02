import 'package:dio/dio.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/parsing.dart';
import 'package:sentorr/torrents/sources/source.dart';

TorrentRelease fakeRelease(
  int id, {
  String name = 'Title 1 2026',
  int? resolution = 1080,
  int seeders = 50,
  int size = 1500000000,
  bool pack = false,
}) {
  final hash = id.toRadixString(16).padLeft(40, '0');
  return TorrentRelease(
    source: TorrentSourceId.pirateBay,
    name: name,
    infoHash: hash,
    magnet: magnetFor(hash, name),
    seeders: seeders,
    sizeBytes: size,
    resolution: resolution,
    isSeasonPack: pack,
  );
}

/// A source answering from [answer]; records every query it receives.
class FakeTorrentSource implements TorrentSource {
  FakeTorrentSource(this.answer);

  final Future<List<TorrentRelease>> Function(TorrentQuery query) answer;
  final queries = <TorrentQuery>[];

  @override
  TorrentSourceId get id => TorrentSourceId.pirateBay;

  @override
  bool supports(TorrentQuery query) => true;

  @override
  Future<List<TorrentRelease>> search(
    TorrentQuery query, {
    CancelToken? cancelToken,
  }) {
    queries.add(query);
    return answer(query);
  }
}
