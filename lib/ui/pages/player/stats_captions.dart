import 'package:media_kit/media_kit.dart';

import '../../../player/stream/subtitles.dart';
import 'stats_readout.dart';

/// Whether captions are chosen, which track, and whether a line is actually
/// reaching the screen. Cue text itself stays out of recordings.
class CaptionStats {
  CaptionStats(this._c, this._d, this._lines);

  final PlaybackSubtitles _c;
  final NativeReadout _d;
  final List<String> _lines;

  SubtitleTrack? get _embedded => _c.embeddedTrack;
  SubtitleDownload? get _file => _embedded == null ? _c.selected : null;

  String? get _source => _embedded != null
      ? 'embedded'
      : _file != null
      ? 'file'
      : null;

  String? get _track => switch (_embedded) {
    final t? => t.title ?? t.language ?? 'Track ${t.id}',
    null => _file?.label,
  };

  bool get _lineOnScreen =>
      _c.visible && _lines.any((l) => l.trim().isNotEmpty);

  StatsSection get section => (
    title: 'Captions',
    rows: [
      (
        'Captions',
        !_c.enabled
            ? 'Off'
            : _c.visible
            ? 'On · showing'
            : 'On · not showing',
      ),
      ('Track', _track == null ? 'None' : '$_track · $_source'),
      if (_file case final f?) ('File status', f.status),
      (
        'Format / language',
        '${_d['current-tracks/sub/codec']} / ${_d['current-tracks/sub/lang']}',
      ),
      ('Delay (s)', _d['sub-delay']),
      ('Line on screen', yesNo(_lineOnScreen)),
      (
        'Available (embedded / files)',
        '${_c.embedded.length} / ${_c.files.length}',
      ),
    ],
  );

  Map<String, Object?> get metrics => {
    'captionsEnabled': _c.enabled,
    'captionsVisible': _c.visible,
    'captionLineOnScreen': _lineOnScreen,
    'captionSource': _source,
    'captionTrack': _track,
    if (_file case final f?) ...{
      'captionFileProgress': double.parse(f.progress.toStringAsFixed(3)),
      'captionFileFailed': f.failed,
    },
    'subCodec': _d.typed('current-tracks/sub/codec'),
    'subLanguage': _d.typed('current-tracks/sub/lang'),
    'subExternal': _d.flag('current-tracks/sub/external'),
    'subDelaySeconds': _d.typed('sub-delay'),
    'embeddedCaptionTracks': _c.embedded.length,
    'captionFiles': _c.files.length,
  };
}
