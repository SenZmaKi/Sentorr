import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../player/launch.dart';
import '../../components/adaptive_sheet.dart';
import 'launch_dialog.dart';

/// Shows the launch dialog whenever a launch starts, from wherever Play was
/// pressed: a hover preview may already be gone, so the app owns it.
/// Dismissing the dialog cancels the launch.
class LaunchHost extends ConsumerStatefulWidget {
  const LaunchHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LaunchHost> createState() => _LaunchHostState();
}

class _LaunchHostState extends ConsumerState<LaunchHost> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(playbackLaunchProvider.select((l) => l != null), (
      _,
      active,
    ) {
      if (active && !_open) _show();
    });
  }

  Future<void> _show() async {
    _open = true;
    final request = ref.read(playbackLaunchProvider)?.request;
    await showAdaptiveSheet<void>(
      context,
      framed: false,
      builder: (_) => const LaunchDialog(),
    );
    _open = false;
    if (!mounted) return;
    final now = ref.read(playbackLaunchProvider)?.request;
    // Barrier, Escape or Back closed it; a finished launch is already null.
    if (identical(now, request)) {
      ref.read(playbackLaunchProvider.notifier).cancel();
    } else if (now != null) {
      // Another launch began while this dialog was closing.
      _show();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
