import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../library/layout.dart';
import '../library/models.dart';
import '../library/notifier.dart';
import '../player/models.dart';
import '../shared/errors/error_reports.dart';
import 'client.dart';
import 'copy_offer.dart';
import 'devices.dart';
import 'peers.dart';
import 'service.dart';

final _log = Logger('sentorr.sync.copies');

final peerCopiesProvider = Provider<PeerCopies>(PeerCopies.new);

/// Copies finished downloads from paired devices into this one's library,
/// one at a time, in the same layout as a download. An interrupted copy
/// resumes where its partial file ends.
class PeerCopies {
  PeerCopies(this._ref);
  final Ref _ref;

  Future<void> _tail = Future.value();

  /// What reachable devices hold of the items [asked] wants that this
  /// device has not got or is not getting.
  CopyOffer offer(bool Function(PlaybackItem item) asked) {
    final devices = _ref.read(devicesProvider);
    final peers = _ref.read(peersProvider);
    return CopyOffer.find([
      for (final d in devices.paired)
        if (peers[d.id] case final peer? when peer.online)
          (id: d.id, name: d.name, media: peer.media),
    ], (item) => asked(item) && downloadable(_ref, item.id));
  }

  /// Starts copying [item] from a device that has it; false when none
  /// does. For automatic downloads, which have no one to ask.
  bool copyIfOffered(PlaybackItem item, {bool automatic = false}) {
    final offer = this.offer((i) => i.id == item.id);
    if (offer.isEmpty) return false;
    start(offer, automatic: automatic);
    return true;
  }

  /// Queues [offer]'s copies; each shows as copying until it is in the
  /// library.
  void start(CopyOffer offer, {bool automatic = false}) {
    final root = _ref.read(downloadsDirectoryProvider);
    for (final copy in offer.copies) {
      final media = copy.media;
      final layout = layoutFor(media.item, root, media.name);
      final entry = LibraryEntry(
        item: media.item,
        downloadId: 'copy:${copy.deviceId}:${media.id}',
        release: media.release,
        fileIndex: media.fileIndex,
        path: p.join(layout.directory, layout.name),
        addedAt: DateTime.now(),
        automatic: automatic,
      );
      _ref
          .read(copyingProvider.notifier)
          .set(CopyProgress(entry, from: copy.deviceName));
      _log.info('Copying ${media.item} from ${copy.deviceName}');
      _tail = _tail.then((_) => _copy(copy, entry));
    }
  }

  /// Stops copying [itemId] and deletes what arrived of it.
  Future<void> cancel(String itemId) async {
    final copy = _ref.read(copyingProvider)[itemId];
    if (copy == null) return;
    _log.info('Cancelled copying ${copy.entry.item}');
    _ref.read(copyingProvider.notifier).end(itemId);
    // A copy under way notices between chunks and deletes it.
    final partial = File(_partial(copy.entry));
    if (await partial.exists()) await partial.delete();
    final metadata = File('${partial.path}.json');
    if (await metadata.exists()) await metadata.delete();
  }

  bool _wanted(String id) =>
      _ref.mounted && _ref.read(copyingProvider).containsKey(id);

  Future<void> _copy(PeerCopy copy, LibraryEntry entry) async {
    final id = entry.id;
    if (!_wanted(id)) return;
    final partial = File(_partial(entry));
    try {
      final route = _ref.read(peersProvider.notifier).route(copy.deviceId);
      if (route == null) {
        throw PeerException("${copy.deviceName} can't be reached");
      }
      await partial.parent.create(recursive: true);
      final version = copy.media.version;
      if (version == null) {
        throw const PeerException('Update the source device before copying');
      }
      final metadata = File('${partial.path}.json');
      final identity = jsonEncode([
        copy.deviceId,
        version,
        copy.media.size,
        copy.media.release.infoHash,
        copy.media.fileIndex,
      ]);
      final same =
          await metadata.exists() && await metadata.readAsString() == identity;
      if (!same && await partial.exists()) await partial.delete();
      var have = same && await partial.exists() ? await partial.length() : 0;
      await metadata.writeAsString(identity, flush: true);
      if (have >= copy.media.size) have = 0;
      final response = await _ref
          .read(syncServiceProvider)
          .client
          .open(
            route.address,
            route.fingerprint,
            '/v1/media/$id',
            headers: {
              HttpHeaders.ifMatchHeader: '"$version"',
              if (have > 0) HttpHeaders.rangeHeader: 'bytes=$have-',
            },
          );
      if (response.statusCode == HttpStatus.ok) {
        have = 0;
      } else if (response.statusCode != HttpStatus.partialContent) {
        await response.drain<void>();
        throw PeerException(
          "${copy.deviceName} doesn't have it any more",
          status: response.statusCode,
        );
      }
      final expectedRange =
          'bytes $have-${copy.media.size - 1}/${copy.media.size}';
      if (response.headers.value(HttpHeaders.etagHeader) != '"$version"' ||
          (response.statusCode == HttpStatus.partialContent &&
              response.headers.value(HttpHeaders.contentRangeHeader) !=
                  expectedRange)) {
        await response.drain<void>();
        throw const PeerException('The source file changed; refresh and retry');
      }
      final sink = partial.openWrite(
        mode: have > 0 ? FileMode.append : FileMode.write,
      );
      var shown = DateTime.now();
      try {
        await for (final chunk in response) {
          if (!_wanted(id)) break;
          sink.add(chunk);
          have += chunk.length;
          if (DateTime.now().difference(shown) > _tick) {
            shown = DateTime.now();
            _progress(entry, copy, have / copy.media.size);
          }
        }
      } finally {
        await sink.close();
      }
      if (!_wanted(id)) {
        if (await partial.exists()) await partial.delete();
        if (await metadata.exists()) await metadata.delete();
        return;
      }
      if (have != copy.media.size) {
        throw PeerException('The copy from ${copy.deviceName} stopped early');
      }
      // A replacement between the server's precondition check and opening
      // the stream must not publish a partial assembled from different files.
      if (_ref.read(peersProvider.notifier).route(copy.deviceId)?.fingerprint !=
          route.fingerprint) {
        throw const PeerException('The source device is no longer paired');
      }
      final verified = await _ref
          .read(syncServiceProvider)
          .client
          .open(
            route.address,
            route.fingerprint,
            '/v1/media/$id',
            method: 'HEAD',
            headers: {HttpHeaders.ifMatchHeader: '"$version"'},
          );
      final unchanged =
          verified.statusCode == HttpStatus.ok &&
          verified.headers.value(HttpHeaders.etagHeader) == '"$version"';
      await verified.drain<void>();
      if (!unchanged) {
        await partial.delete();
        if (await metadata.exists()) await metadata.delete();
        throw const PeerException('The source file changed during copying');
      }
      if (!_wanted(id)) return;
      final target = File(entry.path);
      // Windows will not rename over a file.
      if (await target.exists()) await target.delete();
      await partial.rename(entry.path);
      if (await metadata.exists()) await metadata.delete();
      await _ref
          .read(libraryProvider.notifier)
          .add(
            LibraryEntry(
              item: entry.item,
              downloadId: entry.downloadId,
              release: entry.release,
              fileIndex: entry.fileIndex,
              path: entry.path,
              addedAt: DateTime.now(),
              automatic: entry.automatic,
            ),
          );
      _log.info('Copied ${entry.item} from ${copy.deviceName}');
    } catch (error, stack) {
      if (!_wanted(id)) return;
      // The partial file stays, so trying again resumes it.
      ErrorReports.report(
        "Couldn't copy ${entry.item.name} from ${copy.deviceName}",
        error,
        stack,
      );
    } finally {
      if (_ref.mounted) _ref.read(copyingProvider.notifier).end(id);
    }
  }

  static const _tick = Duration(milliseconds: 250);

  void _progress(LibraryEntry entry, PeerCopy copy, double progress) {
    if (!_wanted(entry.id)) return;
    _ref
        .read(copyingProvider.notifier)
        .set(
          CopyProgress(
            entry,
            from: copy.deviceName,
            progress: progress.clamp(0, 1),
          ),
        );
  }

  static String _partial(LibraryEntry entry) => '${entry.path}.part';
}
