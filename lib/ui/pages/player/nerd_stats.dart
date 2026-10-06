import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../player/diagnostics.dart';
import '../../../player/engine.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'menu_rows.dart';

/// A compact readout independent of auto-hiding playback chrome.
class NerdStats extends StatefulWidget {
  const NerdStats({super.key, required this.engine, required this.onClose});
  final PlaybackEngine engine;
  final VoidCallback onClose;

  @override
  State<NerdStats> createState() => _NerdStatsState();
}

class _NerdStatsState extends State<NerdStats> {
  late final _diagnostics = PlaybackDiagnostics.forPlayer(widget.engine.player);

  @override
  void dispose() {
    _diagnostics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, box) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 72, 12, 96),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: PlayerMenuSurface(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _diagnostics,
                    widget.engine.streaming.status,
                  ]),
                  builder: (context, _) => _content(context, box.biggest),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _content(BuildContext context, Size viewport) {
    final status = widget.engine.streaming.status.value;
    final t = status?.transfer;
    final p = widget.engine.state;
    String v(String key) => _diagnostics.values[key] ?? 'Waiting';
    final rows = <(String, String)>[
      (
        'Viewport',
        '${viewport.width.round()} × ${viewport.height.round()} · ${MediaQuery.devicePixelRatioOf(context).toStringAsFixed(2)}×',
      ),
      (
        'Resolution / source FPS',
        '${v('video-params/w')} × ${v('video-params/h')} / ${v('container-fps')}',
      ),
      ('Video / audio codec', '${v('video-codec')} / ${v('audio-codec-name')}'),
      ('Hardware decoder', v('hwdec-current')),
      (
        'Pixel format / transfer',
        '${v('video-params/pixelformat')} / ${v('video-params/gamma')}',
      ),
      (
        'Estimated FPS / display Hz',
        '${v('estimated-vf-fps')} / ${v('display-fps')}',
      ),
      (
        'Dropped frames (decode / output)',
        '${v('decoder-frame-drop-count')} / ${v('frame-drop-count')}',
      ),
      ('Buffer health (s)', v('demuxer-cache-duration')),
      ('A/V difference (s)', v('avsync')),
      (
        'Playback',
        '${p.buffering
            ? 'Buffering'
            : p.playing
            ? 'Playing'
            : 'Paused'} · ${p.rate}× · volume ${p.volume.round()}%',
      ),
      (
        'Source',
        status?.peer != null
            ? 'Downloaded on ${status!.peer}'
            : status?.localFile != null
            ? 'Downloaded file'
            : status?.stage.name ?? 'Waiting',
      ),
      if (status?.localFile != null && t?.selectedFile != null) ...[
        ('Upload speed', '${sizeLabel(t!.uploadBytesPerSecond)}/s'),
        ('Uploaded', sizeLabel(t.uploadedBytes)),
        (
          'Peers / seeds (connected)',
          '${t.connectedPeers} / ${t.connectedSeeds}',
        ),
      ],
      if (status?.localFile == null && t != null) ...[
        ('File', t.selectedFile?.path ?? 'Waiting for metadata'),
        (
          'Download / upload',
          '${sizeLabel(t.downloadBytesPerSecond)}/s / ${sizeLabel(t.uploadBytesPerSecond)}/s',
        ),
        (
          'Peers / seeds (connected)',
          '${t.connectedPeers} / ${t.connectedSeeds}',
        ),
        (
          'Peers (known / candidates)',
          '${t.knownPeers} / ${t.connectionCandidates}',
        ),
        (
          'File downloaded',
          '${sizeLabel(t.selectedBytes)} / ${t.selectedFile == null ? 'Unknown' : sizeLabel(t.selectedFile!.length)}',
        ),
        (
          'Received / uploaded',
          '${sizeLabel(t.receivedBytes)} / ${sizeLabel(t.uploadedBytes)}',
        ),
        (
          'Read cache / served',
          '${sizeLabel(t.cachedBytes)} / ${sizeLabel(t.servedBytes)}',
        ),
        ('Read requests', '${t.requests}'),
      ],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Stats for nerds', style: context.type.label)),
            IconButton(
              tooltip: 'Copy stats for nerds',
              onPressed: () async {
                final snapshot = [
                  'Sentorr · Stats for nerds',
                  DateTime.now().toIso8601String(),
                  for (final (label, value) in rows) '$label: $value',
                  'Native metrics sampled every second. FPS is an estimate; '
                      'downloaded bytes are not playable buffer.',
                ].join('\n');
                await Clipboard.setData(ClipboardData(text: snapshot));
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Stats copied')));
              },
              icon: const Icon(Icons.copy_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'Close stats for nerds',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    label,
                    style: context.type.caption.copyWith(
                      color: context.colors.foregroundSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Text(value, style: context.type.technical),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Native metrics sampled every second · D to toggle\nFPS is an estimate; downloaded bytes are not playable buffer.',
          style: context.type.caption.copyWith(
            color: context.colors.foregroundMuted,
          ),
        ),
      ],
    );
  }
}
