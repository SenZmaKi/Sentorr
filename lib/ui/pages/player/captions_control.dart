import 'package:flutter/material.dart';

import '../../components/player_control.dart';
import '../../shared/theme/theme.dart';
import 'player_actions.dart';

class CaptionsControl extends StatelessWidget {
  const CaptionsControl({super.key, required this.actions});
  final PlayerActions actions;

  @override
  Widget build(BuildContext context) {
    final captions = actions.captions;
    return ListenableBuilder(
      listenable: captions,
      builder: (context, _) {
        final file = captions.selected ?? captions.files.firstOrNull;
        final downloading = file != null && !file.ready && !file.failed;
        return PlayerControl(
          icon: Icons.closed_caption_outlined,
          tooltip: downloading
              ? 'Captions · ${file.status} (c)'
              : 'Captions (c)',
          selected: captions.enabled,
          onPressed: actions.toggleSubtitles,
          child: downloading
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.closed_caption_outlined),
                    SizedBox.square(
                      dimension: PlayerIconSize.of(context) + Space.s8,
                      child: CircularProgressIndicator(
                        value: file.progress,
                        strokeWidth: 2,
                        color: context.player.foreground,
                        semanticsLabel: file.status,
                      ),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}
