import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../server.dart';
import 'session.dart';

final continuityHostProvider = Provider((ref) => ContinuityHost());

/// The player registers callbacks only while mounted. Reading presence never
/// creates a native player. One receiver may claim a particular session.
class ContinuityHost {
  Future<ContinuitySession?> Function()? snapshot;
  Future<Duration> Function(String session, bool Function() authorized)? pause;
  Future<String?> Function(String session)? caption;
  final destination = ValueNotifier<String?>(null);
  String? _session, _claim;
  Future<Map<String, dynamic>>? _result;

  Future<Map<String, dynamic>> presence() async {
    final session = await snapshot?.call();
    return {
      'version': 1,
      'session': session?.id == _session && _claim != null
          ? null
          : session?.toJson(),
    };
  }

  Future<Map<String, dynamic>> take(
    String receiver,
    String receiverName,
    Map<String, dynamic> body, {
    bool Function()? authorized,
  }) async {
    final allowed = authorized ?? () => true;
    if (!allowed()) {
      throw const SyncRefusal('Device is no longer paired', status: 403);
    }
    final session = body['session'], handoff = body['handoff'];
    if (session is! String ||
        handoff is! String ||
        handoff.isEmpty ||
        handoff.length > 128) {
      throw const FormatException('Invalid handoff');
    }
    final claim = '$receiver:$handoff';
    if (_session == session && _claim == claim && _result != null) {
      return _result!;
    }
    final current = await snapshot?.call();
    if (!allowed()) {
      throw const SyncRefusal('Device is no longer paired', status: 403);
    }
    if (current == null || current.id != session || pause == null) {
      throw const SyncRefusal('Playback has changed. Try again.');
    }
    if (_session != session) {
      _session = session;
      _claim = null;
      _result = null;
    }
    if (_claim != null && _claim != claim) {
      throw const SyncRefusal(
        'This playback has already continued on another device.',
      );
    }
    _claim = claim;
    return _result ??= _finish(session, receiverName, allowed);
  }

  Future<Map<String, dynamic>> _finish(
    String session,
    String name,
    bool Function() allowed,
  ) async {
    try {
      final position = await pause!(session, allowed);
      destination.value = name;
      return {'position': position.inMilliseconds};
    } catch (_) {
      if (_session == session) {
        _claim = null;
        _result = null;
      }
      rethrow;
    }
  }
}
