import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/sync/copy_offer.dart';
import 'package:sentorr/sync/payload.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/ui/shared/copy_prompt.dart';

import '../support/fake_imdb.dart';

final _series = fakeTitle(2, series: true);
final _release = TorrentRelease(
  source: TorrentSourceId.values.first,
  name: 'Show S01',
  infoHash: 'a' * 40,
  magnet: Uri.parse('magnet:?xt=urn:btih:${'a' * 40}'),
  seeders: 10,
  sizeBytes: 1000,
);

PlaybackItem _episode(int n, {int season = 1}) => PlaybackItem(
  title: ImdbTitle(id: 'tt$season$n', title: 'Episode $n'),
  series: _series,
  season: season,
  episode: n,
);

PeerMedia _media(PlaybackItem item) => PeerMedia(
  item: item,
  size: 100,
  name: 'file.mkv',
  release: _release,
  fileIndex: 0,
);

({String id, String name, List<PeerMedia> media}) _device(
  String name,
  List<PlaybackItem> items,
) => (id: name, name: name, media: [for (final i in items) _media(i)]);

void main() {
  test('takes what is wanted, from the first device holding each', () {
    final offer = CopyOffer.find([
      _device('MacBook', [_episode(3), _episode(1), _episode(9, season: 2)]),
      _device('iPad', [_episode(1), _episode(2)]),
    ], (item) => item.season == 1);
    expect(
      [for (final c in offer.copies) c.media.id],
      ['tt11', 'tt12', 'tt13'],
    );
    expect(
      [for (final c in offer.copies) c.deviceName],
      ['MacBook', 'iPad', 'MacBook'],
    );
  });

  test('names episodes as runs', () {
    final offer = CopyOffer.find([
      _device('MacBook', [
        for (final n in [1, 2, 3, 5, 7, 8]) _episode(n),
      ]),
    ], (_) => true);
    expect(offer.what, 'episodes 1–3, 5 and 7–8');
    expect(
      copyMessage(offer, rest: 'the rest of season 1'),
      'Episodes 1–3, 5 and 7–8 are already on MacBook. Copy them over your '
      'network and download the rest of season 1?',
    );
  });

  test('says which device has which', () {
    final offer = CopyOffer.find([
      _device('MacBook', [_episode(1), _episode(2)]),
      _device('iPad', [_episode(4)]),
    ], (_) => true);
    expect(offer.devices, 'MacBook and iPad');
    expect(
      copyMessage(offer, rest: 'the rest of season 1'),
      'Already on your other devices: episodes 1–2 on MacBook and episode 4 '
      'on iPad. Copy them over your network and download the rest of '
      'season 1?',
    );
  });

  test('a single movie', () {
    final movie = PlaybackItem(title: fakeTitle(5));
    final offer = CopyOffer.find([
      _device('MacBook', [movie]),
    ], (i) => i.id == movie.id);
    expect(
      copyMessage(offer),
      'Title 5 is already on MacBook. Copying it over your network is '
      'quicker than downloading it again.',
    );
  });

  test('nothing wanted, nothing offered', () {
    final offer = CopyOffer.find([
      _device('MacBook', [_episode(1)]),
    ], (_) => false);
    expect(offer.isEmpty, true);
  });
}
