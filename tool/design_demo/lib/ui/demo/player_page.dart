import 'package:flutter/material.dart';

import '../components/player_controls.dart';
import '../components/surface.dart';
import '../shared/theme/theme.dart';
import 'sample_data.dart';

/// Player chrome mock: overlay roles stay identical in light and dark modes.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.title});

  final SampleTitle title;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  bool _playing = true;
  double _position = 0.34;
  bool _muted = false;

  String _time(double fraction) {
    final s = (fraction * 8040).round();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${s ~/ 3600}:${two(s % 3600 ~/ 60)}:${two(s % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final tech = context.type.technical.copyWith(color: OverlayColors.foreground);
    return DepthBox(
      style: context.depth.of(SurfaceDepth.panel),
      radius: Radii.panel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.panel),
        child: ColoredBox(
          color: const Color(0xFF000000),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Artwork(hue: widget.title.hue, seed: 3),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: OverlayColors.artworkFade,
                      stops: [0.5, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: Space.s16,
                  left: Space.s16,
                  right: Space.s16,
                  child: Row(
                    children: [
                      PlayerButton(icon: Icons.arrow_back, tooltip: 'Back', onPressed: () {}),
                      const SizedBox(width: Space.s8),
                      Expanded(
                        child: Text(
                          widget.title.title,
                          style: context.type.subtitle.copyWith(color: OverlayColors.foreground),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s12, vertical: Space.s4),
                        decoration: BoxDecoration(
                          color: OverlayColors.controlSurface,
                          borderRadius: BorderRadius.circular(Radii.full),
                        ),
                        child: Text('↓ 12.4 MB/s · 412 peers', style: tech),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: PlayerButton(
                    large: true,
                    icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    tooltip: _playing ? 'Pause' : 'Play',
                    onPressed: () => setState(() => _playing = !_playing),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.s8, 0, Space.s8, Space.s8),
                    child: Column(
                      children: [
                        PlayerSeekBar(
                          position: _position,
                          buffered: (_position + 0.18).clamp(0, 1),
                          onChanged: (v) => setState(() => _position = v),
                        ),
                        Row(
                          children: [
                            PlayerButton(
                              icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              tooltip: _playing ? 'Pause' : 'Play',
                              onPressed: () => setState(() => _playing = !_playing),
                            ),
                            PlayerButton(icon: Icons.replay_10, tooltip: 'Back 10 seconds', onPressed: () {}),
                            PlayerButton(icon: Icons.forward_10, tooltip: 'Forward 10 seconds', onPressed: () {}),
                            PlayerButton(
                              icon: _muted ? Icons.volume_off : Icons.volume_up,
                              tooltip: _muted ? 'Unmute' : 'Mute',
                              onPressed: () => setState(() => _muted = !_muted),
                            ),
                            const SizedBox(width: Space.s8),
                            Text('${_time(_position)} / ${_time(1)}', style: tech),
                            const Spacer(),
                            PlayerButton(icon: Icons.subtitles_outlined, tooltip: 'Subtitles', onPressed: () {}),
                            PlayerButton(icon: Icons.settings_outlined, tooltip: 'Quality', onPressed: () {}),
                            PlayerButton(icon: Icons.fullscreen, tooltip: 'Fullscreen', onPressed: () {}),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
