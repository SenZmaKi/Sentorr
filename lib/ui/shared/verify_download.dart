import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/integrity.dart';
import '../../library/models.dart';
import '../../library/notifier.dart';
import '../components/adaptive_sheet.dart';
import '../components/buttons.dart';
import '../components/dialog_actions.dart';
import '../components/motion.dart';
import '../components/verification_steps.dart';
import 'theme/theme.dart';

Future<void> verifyDownload(BuildContext context, LibraryEntry entry) =>
    showAdaptiveSheet<void>(
      context,
      maxWidth: 440,
      builder: (_) => _Verification(entry: entry),
    );

class _Verification extends ConsumerStatefulWidget {
  const _Verification({required this.entry});
  final LibraryEntry entry;
  @override
  ConsumerState<_Verification> createState() => _VerificationState();
}

class _VerificationState extends ConsumerState<_Verification> {
  IntegrityResult? _result;
  IntegrityProgress? _progress;
  bool _recovering = false, _queued = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    final result = await ref
        .read(libraryIntegrityProvider)
        .check(
          widget.entry,
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
        );
    if (mounted) setState(() => _result = result);
  }

  Future<void> _recover() async {
    setState(() {
      _recovering = true;
      _error = null;
    });
    try {
      await ref.read(libraryIntegrityProvider).recover(widget.entry);
      if (mounted) setState(() => _queued = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not start recovery. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sameFile = widget.entry.sameFile(
      ref
          .watch(libraryProvider)
          .where((e) => e.id == widget.entry.id)
          .firstOrNull,
    );
    final result = _result;
    final checking = result == null && sameFile && !_queued;
    final busy = result == null || _recovering;
    final message = _queued
        ? 'Existing data will be checked and missing pieces downloaded.'
        : !sameFile
        ? 'This download was removed or replaced. Close this check '
              'and select the current download.'
        : _recovering
        ? 'Preparing recovery…'
        : _error ?? result?.message ?? '';
    final c = context.colors;
    final (icon, tint) = _queued
        ? (Icons.downloading_rounded, c.info)
        : !sameFile || _error != null
        ? (Icons.error_outline_rounded, c.error)
        : _recovering
        ? (Icons.build_rounded, c.foregroundSecondary)
        : switch (result?.state) {
            IntegrityState.valid => (
              Icons.check_circle_outline_rounded,
              c.success,
            ),
            IntegrityState.damaged => (Icons.warning_amber_rounded, c.warning),
            _ => (Icons.info_outline_rounded, c.foregroundSecondary),
          };
    final duration = reduceMotion(context) ? Duration.zero : Motion.panel;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _queued
                ? 'Recovery queued'
                : checking
                ? 'Verifying download'
                : switch (result?.state) {
                    IntegrityState.valid => 'No problems found',
                    IntegrityState.damaged => 'Missing or damaged pieces',
                    IntegrityState.inconclusive => 'Some pieces unconfirmed',
                    _ => 'Verification incomplete',
                  },
            style: context.type.title.copyWith(color: c.foreground),
          ),
          const SizedBox(height: Space.s8),
          Text(
            widget.entry.item.label,
            style: context.type.body.copyWith(color: c.foregroundSecondary),
          ),
          const SizedBox(height: Space.s24),
          AnimatedSize(
            duration: duration,
            curve: Motion.change,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: duration,
              child: checking
                  ? VerificationSteps(
                      key: const ValueKey('steps'),
                      progress: _progress,
                    )
                  : Row(
                      key: ValueKey(message),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: IconSizes.control, color: tint),
                        const SizedBox(width: Space.s12),
                        Expanded(
                          child: Text(
                            message,
                            style: context.type.body.copyWith(
                              color: c.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: Space.s24),
          DialogActions(
            children: [
              SButton.ghost(
                label: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
              if (sameFile && !busy && !_queued)
                if (result.state.recoverable)
                  SButton.primary(
                    label: 'Recover missing pieces',
                    onPressed: _recover,
                  )
                else if (result.state == IntegrityState.unavailable)
                  SButton.primary(
                    label: 'Retry verification',
                    onPressed: () {
                      setState(() {
                        _result = null;
                        _progress = null;
                        _error = null;
                      });
                      unawaited(_check());
                    },
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
