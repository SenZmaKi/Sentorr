import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sentorr/ui/components/buttons.dart';
import 'package:sentorr/ui/components/surface.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../runtime/lab_controller.dart';

class LabPlayer extends StatefulWidget {
  const LabPlayer({super.key, required this.lab, required this.video});
  final LabController lab;
  final VideoController video;
  @override
  State<LabPlayer> createState() => _LabPlayerState();
}

class _LabPlayerState extends State<LabPlayer> {
  LabController get lab => widget.lab;
  double? scrubPosition;
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Video(controller: widget.video, controls: NoVideoControls),
              if (lab.active &&
                  (lab.player.state.buffering || lab.monitor.waiting))
                Surface(
                  child: Padding(
                    padding: EdgeInsets.all(Space.s16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: Space.s12),
                        Text(
                          lab.monitor.wait.elapsed.inSeconds >= 30
                              ? 'Still buffering. The source may be too slow. You can stop or try another torrent.'
                              : 'Buffering for smooth playback… ${lab.monitor.cachedSeconds.toStringAsFixed(0)} seconds ready',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.s12),
        Slider(
          value:
              (scrubPosition ??
                      lab.player.state.position.inMilliseconds.toDouble())
                  .clamp(
                    0,
                    lab.player.state.duration.inMilliseconds.toDouble(),
                  ),
          max: lab.player.state.duration.inMilliseconds.toDouble().clamp(
            1,
            double.infinity,
          ),
          label:
              '${((scrubPosition ?? lab.player.state.position.inMilliseconds.toDouble()) / 1000).round()}s',
          onChanged: lab.active
              ? (ms) => setState(() => scrubPosition = ms)
              : null,
          onChangeEnd: lab.active
              ? (ms) {
                  setState(() => scrubPosition = null);
                  unawaited(lab.seek(Duration(milliseconds: ms.round())));
                }
              : null,
        ),
        Text(
          '${lab.player.state.position.inSeconds}s / ${lab.player.state.duration.inSeconds}s',
        ),
        const SizedBox(height: Space.s12),
        Wrap(
          spacing: Space.s8,
          runSpacing: Space.s8,
          children: [
            SButton(
              label: lab.muted ? 'Unmute audio' : 'Mute audio',
              icon: lab.muted ? Icons.volume_off : Icons.volume_up,
              onPressed: lab.toggleMute,
            ),
            SButton(
              label: lab.player.state.playing
                  ? 'Pause playback'
                  : 'Resume playback',
              onPressed: lab.active ? lab.togglePlayback : null,
            ),
            SButton(
              label: 'Seek −30s',
              onPressed: lab.active
                  ? () => lab.seek(
                      Duration(
                        seconds: (lab.player.state.position.inSeconds - 30)
                            .clamp(0, lab.player.state.duration.inSeconds),
                      ),
                    )
                  : null,
            ),
            SButton(
              label: 'Seek +30s',
              onPressed: lab.active
                  ? () => lab.seek(
                      Duration(
                        seconds: (lab.player.state.position.inSeconds + 30)
                            .clamp(0, lab.player.state.duration.inSeconds),
                      ),
                    )
                  : null,
            ),
            SButton(
              label: lab.transferPaused ? 'Resume download' : 'Pause download',
              onPressed: lab.active ? lab.toggleTransfer : null,
            ),
            if (lab.controlled)
              SButton(
                label: lab.seedPaused ? 'Resume seed' : 'Stall seed',
                onPressed: lab.active ? lab.toggleSeed : null,
              ),
          ],
        ),
      ],
    ),
  );
}
