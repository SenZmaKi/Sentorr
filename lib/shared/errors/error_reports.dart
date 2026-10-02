import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../log.dart';

/// A failure worth telling the viewer about, with everything needed to
/// report it: [details] is what the toast's Copy details puts on the
/// clipboard.
class ErrorReport {
  ErrorReport({required this.title, required this.error, this.stack})
    : time = DateTime.now() {
    details = _format(error, stack, time);
  }

  final String title;
  final Object error;
  final StackTrace? stack;
  final DateTime time;
  late final String details;

  /// The error's own message, without Dart's "Exception: " noise.
  String get message {
    final text = error.toString().trim();
    final firstLine = text.split('\n').first;
    return firstLine.replaceFirst(RegExp(r'^(Exception|Error): '), '');
  }
}

/// Routes uncaught errors to the log and to whoever shows them, normally
/// the app's toast layer. Reports raised before anyone listens wait for
/// the first listener, so startup failures still surface.
abstract final class ErrorReports {
  static final _log = Logger('sentorr.errors');
  static final _controller = StreamController<ErrorReport>.broadcast(
    onListen: _replay,
  );
  static final _pending = <ErrorReport>[];
  static final _lastShown = <String, DateTime>{};

  /// The same failure repeats every frame (layout) or every retry; show it
  /// once per window and leave the rest to the log.
  static const repeatWindow = Duration(seconds: 10);
  static const _maxPending = 5;

  static Stream<ErrorReport> get stream => _controller.stream;

  /// Logs [error] and offers it to the viewer under [title].
  static void report(String title, Object error, [StackTrace? stack]) {
    _log.severe(title, error, stack);
    final report = ErrorReport(title: title, error: error, stack: stack);
    final key = '$title|${report.message}';
    final last = _lastShown[key];
    if (last != null && report.time.difference(last) < repeatWindow) return;
    _lastShown[key] = report.time;
    if (_controller.hasListener) {
      _controller.add(report);
    } else if (_pending.length < _maxPending) {
      _pending.add(report);
    }
  }

  /// Sends framework and zone errors through [report] instead of only the
  /// console.
  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      report('Something went wrong', details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report('Unexpected error', error, stack);
      return true;
    };
  }

  static void _replay() {
    final pending = [..._pending];
    _pending.clear();
    // Deliver after the listener's subscription call returns.
    scheduleMicrotask(() => pending.forEach(_controller.add));
  }
}

String _format(Object error, StackTrace? stack, DateTime time) {
  final mode = kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug';
  final buffer = StringBuffer()
    ..writeln('Error: $error')
    ..writeln('Type: ${error.runtimeType}')
    ..writeln('Time: ${time.toIso8601String()}')
    ..writeln(
      'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    )
    ..writeln('Build: $mode, Dart ${Platform.version.split(' ').first}');
  if (stack != null) {
    buffer
      ..writeln()
      ..writeln('Stack trace:')
      ..writeln(stack.toString().trimRight());
  }
  final logs = recentLogLines();
  if (logs.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('Recent log:')
      ..writeAll(logs, '\n');
  }
  return buffer.toString().trimRight();
}
