import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/errors/error_reports.dart';
import '../shared/theme/theme.dart';
import 'buttons.dart';
import 'motion.dart';
import 'toast.dart';

/// Shows each [ErrorReports] failure as a toast in the top-right corner,
/// newest on top, with Copy details for reporting it. Toasts close on
/// their own after [lifetime] unless pointed at.
class ErrorToasts extends StatefulWidget {
  const ErrorToasts({super.key, required this.child});

  static const lifetime = Duration(seconds: 8);
  static const maxVisible = 3;

  final Widget child;

  @override
  State<ErrorToasts> createState() => _ErrorToastsState();
}

class _ErrorToastsState extends State<ErrorToasts> {
  final _reports = <ErrorReport>[];
  late final StreamSubscription<ErrorReport> _subscription;

  /// The layer sits beside the app's navigator, so it brings its own
  /// overlay for the tooltips on its controls.
  late final _layer = OverlayEntry(builder: _buildLayer);

  @override
  void initState() {
    super.initState();
    _subscription = ErrorReports.stream.listen((report) {
      _reports.insert(0, report);
      if (_reports.length > ErrorToasts.maxVisible) _reports.removeLast();
      _layer.markNeedsBuild();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _layer
      ..remove()
      ..dispose();
    super.dispose();
  }

  void _dismiss(ErrorReport report) {
    if (_reports.remove(report)) _layer.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Empty space passes pointer events through to the app.
        Positioned.fill(child: Overlay(initialEntries: [_layer])),
      ],
    );
  }

  Widget _buildLayer(BuildContext context) {
    return Positioned(
      top: Space.s16,
      right: Space.s16,
      left: Space.s16,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final report in _reports)
                Padding(
                  key: ObjectKey(report),
                  padding: const EdgeInsets.only(bottom: Space.s8),
                  child: _ErrorToast(
                    report: report,
                    onDismiss: () => _dismiss(report),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorToast extends StatefulWidget {
  const _ErrorToast({required this.report, required this.onDismiss});

  final ErrorReport report;
  final VoidCallback onDismiss;

  @override
  State<_ErrorToast> createState() => _ErrorToastState();
}

class _ErrorToastState extends State<_ErrorToast> {
  Timer? _close;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  void _schedule() {
    _close?.cancel();
    _close = Timer(ErrorToasts.lifetime, widget.onDismiss);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.report.details));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return MouseRegion(
      // Reading or copying must not race the timer.
      onEnter: (_) => _close?.cancel(),
      onExit: (_) => _schedule(),
      child: Reveal(
        child: Toast(
          tone: ToastTone.error,
          title: report.title,
          message: report.message,
          onDismiss: widget.onDismiss,
          actions: [
            SButton.ghost(
              label: _copied ? 'Copied' : 'Copy details',
              icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
              onPressed: _copy,
            ),
          ],
        ),
      ),
    );
  }
}
