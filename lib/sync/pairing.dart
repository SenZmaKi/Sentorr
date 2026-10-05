import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'client.dart';
import 'devices.dart';
import 'identity.dart';
import 'models.dart';
import 'pairing_code.dart';
import 'server.dart';
import 'service.dart';

final _log = Logger('sentorr.sync.pairing');

sealed class PairingState {
  const PairingState();
}

class PairingIdle extends PairingState {
  const PairingIdle();
}

/// This device waits for another to pair with it.
class PairingOpen extends PairingState {
  const PairingOpen(this.closesAt);
  final DateTime closesAt;
}

/// This device is contacting [name].
class PairingConnecting extends PairingState {
  const PairingConnecting(this.name);
  final String name;
}

/// Both devices show [code]; the viewer checks they match.
class PairingCompare extends PairingState {
  const PairingCompare(this.code, this.peerName, {this.waiting = false});
  final String code, peerName;

  /// This device's viewer chose; the other's has not yet.
  final bool waiting;
}

class PairingDone extends PairingState {
  const PairingDone(this.peerName);
  final String peerName;
}

class PairingFailed extends PairingState {
  const PairingFailed(this.message);
  final String message;
}

/// The joiner, as the host knows it mid-pairing.
class _Joiner {
  _Joiner(this.id, this.name, this.certificatePem, this.commitment);
  final String id, name, certificatePem, commitment;
  final nonce = pairingNonce();
  final decision = Completer<bool>();
  String? code;
}

/// The host, as the joiner knows it mid-pairing.
typedef _Host = ({DeviceAddress address, String id, String name, String pem});

final pairingProvider = NotifierProvider<PairingNotifier, PairingState>(
  PairingNotifier.new,
);

/// Pairs this device with another: one opens for pairing, the other joins
/// it, and both viewers confirm the same six digits.
class PairingNotifier extends Notifier<PairingState> {
  /// How long pairing stays open, and how long each viewer has to choose.
  static const window = Duration(minutes: 5);

  /// How long a joiner may take between the steps before the host moves on.
  static const step = Duration(seconds: 30);

  Timer? _openTimer, _stepTimer;
  _Joiner? _joiner;
  _Host? _host;
  DateTime? _closesAt;

  /// Bumped whenever pairing restarts or ends, so a request still in flight
  /// from before cannot touch what came after.
  int _session = 0;

  @override
  PairingState build() {
    ref.onDispose(() {
      _openTimer?.cancel();
      _stepTimer?.cancel();
    });
    return const PairingIdle();
  }

  DeviceIdentity get _me => ref.read(devicesProvider).identity;

  void _announce(bool open) =>
      unawaited(ref.read(syncServiceProvider).setPairing(open));

  /// Lets one other device pair with this one for [window].
  void open() {
    _reset();
    final closesAt = _closesAt = DateTime.now().add(window);
    state = PairingOpen(closesAt);
    _openTimer = Timer(window, () {
      if (state is PairingOpen) close();
    });
    _announce(true);
  }

  /// Ends pairing, cancelling one in progress.
  void close() {
    final host = _host;
    final compare = state;
    if (host != null && compare is PairingCompare && !compare.waiting) {
      // Tell the host now rather than leaving it to time out.
      unawaited(_tell(host, false));
    }
    _reset();
    _announce(false);
    state = const PairingIdle();
  }

  Future<void> _tell(_Host host, bool accepted) async {
    try {
      await ref.read(syncServiceProvider).client.pair(host.address, 'confirm', {
        'accepted': accepted,
      });
    } catch (error) {
      _log.fine('Could not tell ${host.name}: $error');
    }
  }

  void _reset() {
    _session++;
    _openTimer?.cancel();
    _stepTimer?.cancel();
    if (_joiner?.decision.isCompleted == false) {
      _joiner!.decision.complete(false);
    }
    _joiner = null;
    _host = null;
    _closesAt = null;
  }

  void _fail(String message) {
    _log.info('Pairing failed: $message');
    _reset();
    _announce(false);
    state = PairingFailed(message);
  }

  /// The host drops its joiner and waits for another, if there is time.
  void _release(String why) {
    _log.info('Dropping joiner: $why');
    final closesAt = _closesAt;
    if (closesAt == null || !closesAt.isAfter(DateTime.now())) {
      return close();
    }
    _stepTimer?.cancel();
    if (_joiner?.decision.isCompleted == false) {
      _joiner!.decision.complete(false);
    }
    _joiner = null;
    _session++;
    state = PairingOpen(closesAt);
    _announce(true);
  }

  /// Pairs with the device at [address], which must be open for pairing.
  Future<void> join(DeviceAddress address, {String? name}) async {
    _reset();
    _announce(false);
    final session = _session;
    state = PairingConnecting(name ?? address.host);
    final client = ref.read(syncServiceProvider).client;
    final me = _me;
    final nonce = pairingNonce();
    try {
      final start = await client.pair(address, 'start', {
        'id': me.id,
        'name': me.name,
        'certificate': me.certificatePem,
        'commitment': pairingCommitment(nonce),
      });
      if (session != _session) return;
      final body = start.body;
      final pem = body['certificate'], id = body['id'];
      final hostName = body['name'], hostNonce = body['nonce'];
      if (pem is! String ||
          id is! String ||
          hostName is! String ||
          hostNonce is! String ||
          id == me.id ||
          fingerprintOfPem(pem) != start.fingerprint) {
        return _fail("That device's answer didn't add up");
      }
      await client.pair(address, 'reveal', {'nonce': nonce});
      if (session != _session) return;
      _host = (address: address, id: id, name: hostName, pem: pem);
      state = PairingCompare(
        pairingCode(
          joinerFingerprint: me.fingerprint,
          hostFingerprint: start.fingerprint,
          joinerNonce: nonce,
          hostNonce: hostNonce,
        ),
        hostName,
      );
      _stepTimer = Timer(window, () => _fail('Pairing timed out'));
    } catch (error) {
      if (session == _session) _fail(_explain(error, name ?? address.host));
    }
  }

  /// What went wrong, as the viewer should read it.
  String _explain(Object error, String device) => switch (error) {
    TimeoutException() =>
      "$device didn't respond. Check that it has "
          'Pair a device open and is on the same network.',
    SyncRefusal(message: 'Not open for pairing') ||
    PeerException(message: 'Not open for pairing') =>
      '$device isn’t ready. Open Settings → Devices → Pair a device on it, '
          'then try again.',
    _ => '$error',
  };

  /// The viewer's answer to whether both devices show the same code.
  Future<void> decide(bool match) async {
    final compare = state;
    if (compare is! PairingCompare || compare.waiting) return;
    final session = _session;
    if (_joiner case final joiner?) {
      joiner.decision.complete(match);
      if (!match) return _fail('Pairing cancelled');
      state = PairingCompare(compare.code, compare.peerName, waiting: true);
      return;
    }
    final host = _host;
    if (host == null) return;
    if (!match) {
      // Do not make the viewer wait on the network to back out.
      unawaited(_tell(host, false));
      return _fail('Pairing cancelled');
    }
    state = PairingCompare(compare.code, compare.peerName, waiting: true);
    try {
      final answer = await ref.read(syncServiceProvider).client.pair(
        host.address,
        'confirm',
        {'accepted': true},
        timeout: window + const Duration(seconds: 10),
      );
      if (session != _session) return;
      if (answer.body['accepted'] != true) {
        return _fail("${host.name} didn't confirm the code");
      }
      await _paired(
        PairedDevice(
          id: host.id,
          name: host.name,
          certificatePem: host.pem,
          pairedAt: DateTime.now(),
          address: host.address,
        ),
        session,
      );
    } catch (error) {
      if (session == _session) _fail(_explain(error, host.name));
    }
  }

  // The host's side, called by the server.

  Future<Map<String, dynamic>> hostStart(Map<String, dynamic> body) async {
    if (state is! PairingOpen || _joiner != null) {
      throw const SyncRefusal('Not open for pairing');
    }
    final id = body['id'], name = body['name'];
    final pem = body['certificate'], commitment = body['commitment'];
    if (id is! String ||
        name is! String ||
        pem is! String ||
        commitment is! String ||
        id == _me.id) {
      throw const SyncRefusal('Bad request', status: 400);
    }
    _log.info('$name ($id) is pairing');
    final joiner = _joiner = _Joiner(id, name, pem, commitment);
    state = PairingConnecting(name);
    // One joiner at a time; and one that goes quiet must not hold the slot.
    // The announcement is left alone: restarting it mid-handshake makes
    // other devices lose and re-find this one.
    _stepTimer?.cancel();
    _stepTimer = Timer(step, () {
      if (_joiner == joiner && joiner.code == null) {
        _release("$name didn't finish");
      }
    });
    final me = _me;
    return {
      'id': me.id,
      'name': me.name,
      'certificate': me.certificatePem,
      'nonce': joiner.nonce,
    };
  }

  Future<Map<String, dynamic>> hostReveal(Map<String, dynamic> body) async {
    final joiner = _joiner;
    final nonce = body['nonce'];
    if (joiner == null || joiner.code != null) {
      throw const SyncRefusal('Not pairing');
    }
    if (nonce is! String || pairingCommitment(nonce) != joiner.commitment) {
      _release("${joiner.name}'s pairing didn't add up");
      throw const SyncRefusal('Commitment mismatch');
    }
    final String code;
    try {
      code = pairingCode(
        joinerFingerprint: fingerprintOfPem(joiner.certificatePem),
        hostFingerprint: _me.fingerprint,
        joinerNonce: nonce,
        hostNonce: joiner.nonce,
      );
    } catch (_) {
      _release("${joiner.name}'s certificate was unreadable");
      throw const SyncRefusal('Bad certificate', status: 400);
    }
    joiner.code = code;
    _stepTimer?.cancel();
    _stepTimer = Timer(window, () => _fail('Pairing timed out'));
    state = PairingCompare(code, joiner.name);
    return const {};
  }

  Future<Map<String, dynamic>> hostConfirm(
    Map<String, dynamic> body,
    DeviceAddress from,
  ) async {
    final joiner = _joiner;
    // Cancelled or timed out here first.
    if (joiner == null || joiner.code == null) return {'accepted': false};
    if (body['accepted'] != true) {
      _fail("The codes didn't match on ${joiner.name}");
      return {'accepted': false};
    }
    final session = _session;
    final accepted = await joiner.decision.future;
    if (!accepted || _joiner != joiner || session != _session) {
      return {'accepted': false};
    }
    try {
      await _paired(
        PairedDevice(
          id: joiner.id,
          name: joiner.name,
          certificatePem: joiner.certificatePem,
          pairedAt: DateTime.now(),
          address: from,
        ),
        session,
      );
    } catch (error) {
      return {'accepted': false};
    }
    return {'accepted': true};
  }

  /// Saves [device] as paired; a failure ends pairing and rethrows.
  Future<void> _paired(PairedDevice device, int session) async {
    try {
      await ref.read(syncServiceProvider).addPaired(device);
    } catch (error) {
      if (session == _session) _fail("Couldn't save the pairing: $error");
      rethrow;
    }
    if (session != _session) return;
    _reset();
    _announce(false);
    state = PairingDone(device.name);
  }
}
