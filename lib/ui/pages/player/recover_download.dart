import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/integrity.dart';
import '../../../library/models.dart';
import '../../../library/notifier.dart';
import '../../components/buttons.dart';
import '../../components/verification_steps.dart';
import 'stage_states.dart';

/// Runs once for this failed local playback, including failures during a seek
/// or in the middle of the movie. A decoder error is not a corruption verdict.
class LocalPlaybackProblem extends ConsumerStatefulWidget {
  const LocalPlaybackProblem({
    super.key,
    required this.entry,
    required this.onReady,
    required this.onBack,
    this.onRetry,
    this.onSkip,
    this.onChoose,
    required this.chooseLabel,
  });
  final LibraryEntry entry;
  final VoidCallback onReady, onBack;
  final VoidCallback? onRetry, onSkip, onChoose;
  final String chooseLabel;
  @override
  ConsumerState<LocalPlaybackProblem> createState() =>
      _LocalPlaybackProblemState();
}

class _LocalPlaybackProblemState extends ConsumerState<LocalPlaybackProblem> {
  IntegrityResult? _result;
  IntegrityProgress? _progress;
  bool _recovering = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  @override
  void didUpdateWidget(LocalPlaybackProblem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recovery replaces the library record before its future completes.
    // Keep this state alive so it can hand playback to the repaired download;
    // starting another verifier here races the active torrent's disk writes.
    if (!_recovering && !oldWidget.entry.sameFile(widget.entry)) {
      _result = null;
      _progress = null;
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    final generation = ++_generation;
    final result = await ref
        .read(libraryIntegrityProvider)
        .check(
          widget.entry,
          onProgress: (progress) {
            if (mounted && generation == _generation) {
              setState(() => _progress = progress);
            }
          },
        );
    if (mounted && generation == _generation) {
      setState(() => _result = result);
    }
  }

  Future<void> _recover() async {
    setState(() => _recovering = true);
    try {
      await ref.read(libraryIntegrityProvider).recover(widget.entry);
      if (mounted) widget.onReady();
    } catch (error) {
      if (mounted) {
        setState(() {
          _recovering = false;
          _result = const IntegrityResult(
            IntegrityState.unavailable,
            'Recovery could not start. Check your connection and retry verification.',
          );
        });
      }
    }
    // Keep the handoff in progress until playback replaces this error view.
    // Reopening is async: the library's replacement can reach the next frame
    // after onReady returns, otherwise didUpdateWidget starts a second check.
  }

  @override
  Widget build(BuildContext context) {
    // If the entry was removed or replaced, do not recover the stale file.
    final sameFile = widget.entry.sameFile(
      ref
          .watch(libraryProvider)
          .where((e) => e.id == widget.entry.id)
          .firstOrNull,
    );
    final result = _result;
    return PlaybackProblem(
      message: _recovering
          ? 'Preparing recovery…'
          : result == null
          ? 'Playback failed. Checking the file for missing or damaged pieces.'
          : result.state == IntegrityState.valid
          ? '${result.message} Playback may have failed because of the format '
                'or player. Downloading the same bytes again is unlikely to help.'
          : result.state == IntegrityState.damaged
          ? result.message
          : '${result.message} The cause of the playback failure is unconfirmed.',
      progress: result == null && !_recovering
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: VerificationSteps(progress: _progress, onMedia: true),
            )
          : null,
      onBack: widget.onBack,
      onSkip: widget.onSkip,
      onChoose: widget.onChoose,
      chooseLabel: widget.chooseLabel,
      onRetry: result?.state == IntegrityState.valid ? widget.onRetry : null,
      recovery: !sameFile || _recovering || result == null
          ? null
          : result.state.recoverable
          ? SButton(
              label: 'Recover missing pieces',
              icon: Icons.build_rounded,
              onPressed: _recover,
            )
          : result.state == IntegrityState.unavailable
          ? SButton(
              label: 'Retry verification',
              icon: Icons.refresh_rounded,
              onPressed: () {
                setState(() {
                  _result = null;
                  _progress = null;
                });
                unawaited(_check());
              },
            )
          : null,
    );
  }
}
