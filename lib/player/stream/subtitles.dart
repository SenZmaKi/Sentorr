import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:torrent_stream/torrent_stream.dart';

class SubtitleDownload {
  const SubtitleDownload(
    this.file, {
    this.bytes = 0,
    this.path,
    this.failed = false,
  });
  final TorrentStreamFile file;
  final int bytes;
  final String? path;
  final bool failed;
  bool get ready => path != null && !failed;
  double get progress => (bytes / file.length).clamp(0, 1);
  String get label => p.basenameWithoutExtension(file.path);
  String get status => failed
      ? 'Unavailable'
      : ready
      ? 'Ready'
      : 'Downloading ${(progress * 100).floor()}%';
}

/// Captions intent outlives an item's download. Native commands are serialized
/// so a late attachment cannot override Off or a newer selection. Off hides
/// the Flutter overlay without deselecting and flushing mpv's packet cache.
class PlaybackSubtitles extends ChangeNotifier {
  PlaybackSubtitles(this.player);
  final Player player;
  List<SubtitleDownload> files = const [];
  bool enabled = false;
  bool _explicit = false, _opened = false;
  int? selectedFile;
  SubtitleTrack? _embedded;
  String? _applied, _selectedKey;
  final _imports = <String, SubtitleTrack>{};
  Set<String>? _originalTrackIds;
  final _sidecarTitles = <String>{};
  int _generation = 0;
  Future<void> _commands = Future.value();
  StreamSubscription<List<TorrentSnapshot>>? _updates;

  SubtitleTrack? get _desired =>
      _embedded ??
      (selected?.ready == true
          ? SubtitleTrack.uri(selected!.path!, title: selected!.label)
          : null);
  static String _key(SubtitleTrack track) => '${track.uri}:${track.id}';

  /// Hide stale text while another track or a pending download is selected.
  bool get visible =>
      enabled && _opened && _desired != null && _selectedKey == _key(_desired!);

  bool get available => files.isNotEmpty || embedded.isNotEmpty;
  List<SubtitleTrack> get embedded => player.state.tracks.subtitle
      .where(
        (t) =>
            t.id != 'no' &&
            t.id != 'auto' &&
            !t.uri &&
            !t.data &&
            (_originalTrackIds == null ||
                _originalTrackIds!.contains(t.id) ||
                !_sidecarTitles.contains(t.title)),
      )
      .toList();
  SubtitleDownload? get selected =>
      files.where((f) => f.file.index == selectedFile).firstOrNull;
  String get status => !enabled ? 'Off' : selected?.status ?? 'On';

  Future<void> reset() {
    _generation++;
    unawaited(_updates?.cancel());
    _updates = null;
    files = const [];
    selectedFile = null;
    _embedded = null;
    _applied = _selectedKey = null;
    _imports.clear();
    _originalTrackIds = null;
    _sidecarTitles.clear();
    _opened = false;
    notifyListeners();
    return _commands;
  }

  void watch(TorrentStreamSession session, List<TorrentStreamFile> sidecars) {
    final generation = _generation;
    files = [for (final f in sidecars) SubtitleDownload(f)];
    notifyListeners();
    if (sidecars.isEmpty) return;
    void observe(List<TorrentSnapshot> torrents) {
      if (generation != _generation) return;
      final torrent = torrents
          .where((t) => t.infoHash == session.infoHash)
          .firstOrNull;
      if (torrent == null) return;
      files = [for (final f in files) _download(f, torrent)];
      notifyListeners();
      _apply();
    }

    _updates = session.engine.states.listen(
      observe,
      onError: (Object _) {
        if (generation == _generation) _failDownloads();
      },
    );
    final snapshot = session.engine.torrent(session.infoHash!);
    if (snapshot != null) observe([snapshot]);
    unawaited(
      session.engine
          .want(session.infoHash!, session.owner, {
            for (final f in sidecars) f.index,
          })
          .catchError((Object _) {
            if (generation == _generation) _failDownloads();
          }),
    );
  }

  SubtitleDownload _download(SubtitleDownload value, TorrentSnapshot torrent) {
    final file = value.file;
    final bytes = torrent.bytesOf(file.index).clamp(0, file.length);
    final path = p.normalize(p.join(torrent.savePath, file.path));
    final safe = p.isWithin(p.normalize(torrent.savePath), path);
    return SubtitleDownload(
      file,
      bytes: bytes,
      path: bytes == file.length && safe ? path : null,
      failed: value.failed || !safe || torrent.error != null,
    );
  }

  void _failDownloads() {
    files = [
      for (final f in files)
        SubtitleDownload(
          f.file,
          bytes: f.bytes,
          path: f.path,
          failed: !f.ready,
        ),
    ];
    notifyListeners();
  }

  void opened() {
    _opened = true;
    final track = player.state.track.subtitle;
    if (track.id != 'no' && track.id != 'auto') {
      _selectedKey = _key(track);
      if (!_explicit) _embedded = track;
    }
    if (!_explicit) enabled = _embedded != null;
    _apply();
    notifyListeners();
  }

  void toggle() => enabled ? off() : on();
  void on() {
    _explicit = true;
    enabled = true;
    if (selectedFile == null && _embedded == null) {
      _embedded = embedded.firstOrNull;
      if (_embedded == null) selectedFile = files.firstOrNull?.file.index;
    }
    _apply();
    notifyListeners();
  }

  void off() {
    _explicit = true;
    enabled = false;
    _apply();
    notifyListeners();
  }

  void chooseFile(int index) {
    selectedFile = index;
    _embedded = null;
    _explicit = enabled = true;
    _apply();
    notifyListeners();
  }

  void chooseTrack(SubtitleTrack track) {
    selectedFile = null;
    _embedded = track;
    _explicit = enabled = true;
    _apply();
    notifyListeners();
  }

  void _apply() {
    if (!_opened || !enabled) return;
    if (selectedFile == null && _embedded == null) {
      _embedded = embedded.firstOrNull;
      if (_embedded == null) selectedFile = files.firstOrNull?.file.index;
    }
    final sidecar = selected;
    final track = _desired;
    if (track == null) return;
    final key = _key(track);
    if (_applied == key) return;
    _applied = key;
    if (track.uri) {
      // MediaKit also reports imported files as numeric native tracks.
      // Keep them in the sidecar rows, while retaining original embedded ones.
      _originalTrackIds ??= {for (final t in embedded) t.id};
      _sidecarTitles.add(track.title!);
    }
    final generation = _generation;
    _commands = _commands.then((_) async {
      if (generation != _generation || _applied != key) return;
      if (!enabled) {
        _applied = null;
        return;
      }
      try {
        // A previously imported sidecar is selected by its native ID, rather
        // than sub-add, which would create a duplicate track on every return.
        await player.setSubtitleTrack(_imports[track.id] ?? track);
        if (generation != _generation) return;
        _selectedKey = key;
        if (track.uri && !_imports.containsKey(track.id)) {
          final native = player.platform;
          final id = native is NativePlayer
              ? await native.getProperty('sid')
              : null;
          if (generation != _generation) return;
          if (id != null && id != 'no' && id != 'auto') {
            _imports[track.id] = SubtitleTrack(id, track.title, track.language);
          }
        }
        notifyListeners();
      } on Object {
        if (generation != _generation || _applied != key) return;
        _applied = null;
        if (sidecar != null) {
          files = [
            for (final f in files)
              f == sidecar
                  ? SubtitleDownload(f.file, bytes: f.bytes, failed: true)
                  : f,
          ];
        }
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_updates?.cancel());
    super.dispose();
  }
}
