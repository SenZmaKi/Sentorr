import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/notifier.dart';
import '../../sync/copy_offer.dart';
import '../components/adaptive_sheet.dart';
import '../components/buttons.dart';
import '../components/dialog_actions.dart';
import '../components/progress_track.dart';
import 'theme/theme.dart';

enum CopyChoice { copy, download }

/// Asks whether to copy what [offer] found on paired devices instead of
/// downloading it, copying once the auto action countdown runs out; null
/// when the viewer cancels. [rest] names what would still download, e.g.
/// "the rest of season 2"; null when the offer covers the whole request.
Future<CopyChoice?> askToCopy(
  BuildContext context,
  CopyOffer offer, {
  String? rest,
}) => showAdaptiveSheet<CopyChoice>(
  context,
  maxWidth: 480,
  builder: (_) => _CopyPrompt(offer: offer, rest: rest),
);

/// Any touch, scroll or key stops the countdown.
class _CopyPrompt extends ConsumerStatefulWidget {
  const _CopyPrompt({required this.offer, this.rest});

  final CopyOffer offer;
  final String? rest;

  @override
  ConsumerState<_CopyPrompt> createState() => _CopyPromptState();
}

class _CopyPromptState extends ConsumerState<_CopyPrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: ref.read(settingsProvider).torrents.autoActionDelay,
  );
  bool _counting = true;

  @override
  void initState() {
    super.initState();
    _countdown
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _counting) {
          _choose(CopyChoice.copy);
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  void _interrupt() {
    if (!_counting) return;
    _countdown.stop();
    setState(() => _counting = false);
  }

  void _choose(CopyChoice? choice) {
    _counting = false;
    Navigator.pop(context, choice);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rest = widget.rest;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _interrupt(),
      onPointerSignal: (_) => _interrupt(),
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, _) {
          _interrupt();
          return KeyEventResult.ignored;
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Copy from ${widget.offer.devices}?',
                style: context.type.title.copyWith(color: c.foreground),
              ),
              const SizedBox(height: Space.s8),
              Text(
                copyMessage(widget.offer, rest: rest),
                style: context.type.body.copyWith(color: c.foregroundSecondary),
              ),
              const SizedBox(height: Space.s24),
              if (_counting) ...[
                ProgressTrack(progress: _countdown),
                const SizedBox(height: Space.s16),
              ],
              // Rebuilt as the countdown ticks, for its seconds label.
              AnimatedBuilder(
                animation: _countdown,
                builder: (context, _) => DialogActions(
                  children: [
                    SButton.ghost(
                      label: 'Cancel',
                      onPressed: () => _choose(null),
                    ),
                    SButton(
                      label: rest == null ? 'Download instead' : 'Download all',
                      onPressed: () => _choose(CopyChoice.download),
                    ),
                    SButton.primary(
                      label: _copyLabel(),
                      onPressed: () => _choose(CopyChoice.copy),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _copyLabel() {
    final label = widget.rest == null ? 'Copy' : 'Copy and download the rest';
    if (!_counting) return label;
    final seconds =
        (_countdown.duration!.inMilliseconds * (1 - _countdown.value) / 1000)
            .ceil();
    return '$label in ${seconds}s';
  }
}

/// What the prompt says, e.g. "Episodes 1–3 and 5 are already on MacBook.
/// Copy them over your network and download the rest of season 2?"
String copyMessage(CopyOffer offer, {String? rest}) {
  final several = offer.copies.length > 1;
  final had = {for (final c in offer.copies) c.deviceName}.length == 1
      ? '${_capital(offer.what)} ${several ? 'are' : 'is'} already on '
            '${offer.devices}.'
      : 'Already on your other devices: ${offer.summary}.';
  final them = several ? 'them' : 'it';
  return rest == null
      ? '$had Copying $them over your network is quicker than downloading '
            '$them again.'
      : '$had Copy $them over your network and download $rest?';
}

String _capital(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
