import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../../player/diagnostics.dart';
import '../../../player/engine.dart';
import '../../../settings/notifier.dart';
import '../../../shared/persistence/app_paths.dart';
import '../../shared/theme/theme.dart';
import 'nerd_stats_controls.dart';
import 'nerd_stats_rows.dart';
import 'nerd_stats_sections.dart';
import 'stats_export.dart';
import 'stats_recorder.dart';
import 'stats_session.dart';

/// A see-through readout over the picture, independent of auto-hiding
/// playback chrome. A recording keeps sampling while the readout is hidden
/// ([visible] false), collapsing to a chip that reopens it, and is kept in
/// the diagnostics folder if the player closes before it is exported.
class NerdStats extends ConsumerStatefulWidget {
  const NerdStats({
    super.key,
    required this.engine,
    required this.title,
    required this.visible,
    required this.onToggle,
    required this.onRecordingChanged,
  });

  final PlaybackEngine engine;
  final String title;
  final bool visible;
  final VoidCallback onToggle;
  final ValueChanged<bool> onRecordingChanged;

  @override
  ConsumerState<NerdStats> createState() => _NerdStatsState();
}

class _NerdStatsState extends ConsumerState<NerdStats> {
  late final _diagnostics = PlaybackDiagnostics.forPlayer(
    widget.engine.player,
    source: () => (
      widget.engine.streaming.item?.id,
      widget.engine.streaming.status.value?.torrent?.release.infoHash,
      widget.engine.streaming.status.value?.stage,
    ),
    engine: widget.engine.streaming.diagnose,
  );
  late final _recorder = StatsRecorder(
    diagnostics: _diagnostics,
    snapshot: () => _snapshot,
    events: widget.engine.events,
    paths: _paths,
    describe: () => describeStatsSession(
      settings: ref.read(settingsProvider),
      paths: _paths,
      diagnostics: _diagnostics,
    ),
  );

  /// Read up front: closing the player must not need `ref`.
  AppPaths? _paths;
  Size _viewport = Size.zero;
  double _ratio = 1;

  NerdStatsSnapshot get _snapshot => NerdStatsSnapshot(
    diagnostics: _diagnostics,
    playback: widget.engine.state,
    status: widget.engine.streaming.status.value,
    captions: widget.engine.streaming.subtitles,
    title: widget.title,
    itemId: widget.engine.streaming.item?.id,
    viewport: _viewport,
    pixelRatio: _ratio,
  );

  @override
  void initState() {
    super.initState();
    try {
      _paths = ref.read(appPathsProvider);
    } catch (_) {
      // Bare test hosts have no app folders; recordings then aren't kept.
    }
    // One sample per diagnostics tick (each second).
    _diagnostics.addListener(_recorder.sample);
  }

  @override
  void dispose() {
    // The player is closing: keep what was recorded rather than lose it.
    unawaited(_recorder.keepIfUnexported().catchError((Object _) => null));
    _diagnostics.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    final current = _recorder.recording;
    setState(
      current == null || current.stopped ? _recorder.start : _recorder.stop,
    );
    widget.onRecordingChanged(true);
  }

  void _recent() {
    setState(_recorder.recent);
    widget.onRecordingChanged(true);
  }

  void _discard() {
    setState(_recorder.discard);
    widget.onRecordingChanged(false);
  }

  Future<void> _export(Future<bool> Function(String json) send) async {
    final recording = _recorder.recording;
    String message;
    try {
      final json = await _recorder.encode();
      if (json == null || !await send(json)) return;
      recording?.exported = true;
      message = 'Stats recording exported';
    } catch (_) {
      message = 'Could not export stats';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copySnapshot() async {
    final snapshot = [
      'Sentorr · Stats for nerds',
      DateTime.now().toIso8601String(),
      for (final section in _snapshot.sections) ...[
        '',
        section.title,
        for (final (label, value) in section.rows) '$label: $value',
      ],
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: snapshot));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Stats copied')));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, box) {
        _viewport = box.biggest;
        _ratio = MediaQuery.devicePixelRatioOf(context);
        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 72, 12, 96),
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _diagnostics,
                widget.engine.streaming.status,
              ]),
              builder: (context, _) {
                final recording = _recorder.recording;
                if (widget.visible) {
                  return _panel(context, wide: box.maxWidth >= 1040);
                }
                return recording == null
                    ? const SizedBox.shrink()
                    : RecordingChip(
                        recording: recording,
                        onOpen: widget.onToggle,
                      );
              },
            ),
          ),
        );
      },
    ),
  );

  Widget _panel(BuildContext context, {required bool wide}) {
    final recording = _recorder.recording;
    final recordingLive = recording != null && !recording.stopped;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: wide ? 1000 : 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: statsSurface,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.s12,
            Space.s4,
            Space.s4,
            Space.s12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Stats for nerds',
                      style: context.type.label.copyWith(
                        color: OverlayColors.foreground,
                      ),
                    ),
                  ),
                  if (recording != null) RecordingBadge(recording: recording),
                  StatsIconButton(
                    tooltip: recordingLive ? 'Stop recording' : 'Record stats',
                    icon: recordingLive
                        ? Icons.stop_circle_outlined
                        : Icons.radio_button_checked_rounded,
                    color: recordingLive
                        ? OverlayColors.recording
                        : OverlayColors.foreground,
                    onPressed: _toggleRecording,
                  ),
                  if (!recordingLive)
                    StatsIconButton(
                      tooltip: 'Export the last 15 minutes',
                      icon: Icons.history_rounded,
                      onPressed: _recent,
                    ),
                  StatsIconButton(
                    tooltip: 'Copy stats for nerds',
                    icon: Icons.copy_outlined,
                    onPressed: _copySnapshot,
                  ),
                  StatsIconButton(
                    tooltip: 'Close stats for nerds',
                    icon: Icons.close_rounded,
                    onPressed: widget.onToggle,
                  ),
                ],
              ),
              if (recording != null && recording.stopped)
                RecordingExportBar(
                  recording: recording,
                  onCopy: () => _export((json) async {
                    await StatsExport.copy(json);
                    return true;
                  }),
                  onSave: () => _export(
                    (json) => StatsExport.save(
                      json,
                      widget.title,
                      recording.startedAt,
                    ),
                  ),
                  onDiscard: _discard,
                ),
              StatsSectionList(
                sections: _snapshot.sections,
                columns: wide ? 2 : 1,
              ),
              const SizedBox(height: Space.s8),
              Text(
                'Sampled every second · D to toggle · recordings include '
                'the playback events before them\n'
                'FPS is an estimate; downloaded bytes are not playable buffer.',
                style: context.type.caption.copyWith(
                  color: OverlayColors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
