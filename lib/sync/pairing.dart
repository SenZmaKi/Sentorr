import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

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

  Timer? _timer;
  _Joiner? _joiner;
  _Host? _host;

  @override
  PairingState build() {
    ref.onDispose(() => _timer?.cancel());
    return const PairingIdle();
  }

  DeviceIdentity get _me => ref.read(devicesProvider).identity;

  /// Lets one other device pair with this one for [window].
  void open() {
    _reset();
    state = PairingOpen(DateTime.now().add(window));
    _timer = Timer(window, () {
      if (state is PairingOpen) close();
    });
    unawaited(ref.read(syncServiceProvider).setPairing(true));
  }

  /// Ends pairing, cancelling one in progress.
  void close() {
    _reset();
    state = const PairingIdle();
  }

  void _reset() {
    _timer?.cancel();
    if (_joiner?.decision.isCompleted == false) {
      _joiner!.decision.complete(false);
    }
    _joiner = null;
    _host = null;
    unawaited(ref.read(syncServiceProvider).setPairing(false));
  }

  void _fail(String message) {
    _log.info('Pairing failed: $message');
    _reset();
    state = PairingFailed(message);
  }

  /// Pairs with the device at [address], which must be open for pairing.
  Future<void> join(DeviceAddress address, {String? name}) async {
    _reset();
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
      final body = start.body;
      final pem = body['certificate'], id = body['id'];
      final hostName = body['name'], hostNonce = body['nonce'];
      if (pem is! String ||
          id is! String ||
          hostName is! String ||
          hostNonce is! String ||
          fingerprintOfPem(pem) != start.fingerprint) {
        return _fail("That device's answer didn't add up");
      }
      await client.pair(address, 'reveal', {'nonce': nonce});
      if (state is! PairingConnecting) return;
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
      _timer = Timer(window, () => _fail('Pairing timed out'));
    } catch (error) {
      if (state is PairingConnecting) _fail('$error');
    }
  }

  /// The viewer's answer to whether both devices show the same code.
  Future<void> decide(bool match) async {
    final compare = state;
    if (compare is! PairingCompare || compare.waiting) return;
    if (_joiner case final joiner?) {
      joiner.decision.complete(match);
      if (!match) return _fail('Pairing cancelled');
      state = PairingCompare(compare.code, compare.peerName, waiting: true);
      return;
    }
    final host = _host;
    if (host == null) return;
    state = PairingCompare(compare.code, compare.peerName, waiting: true);
    try {
      final answer = await ref.read(syncServiceProvider).client.pair(
        host.address,
        'confirm',
        {'accepted': match},
        timeout: window + const Duration(seconds: 10),
      );
      if (!match) return _fail('Pairing cancelled');
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
      );
    } catch (error) {
      if (_host == host) _fail('$error');
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
      _fail("${joiner.name}'s pairing didn't add up");
      throw const SyncRefusal('Commitment mismatch');
    }
    final code = joiner.code = pairingCode(
      joinerFingerprint: fingerprintOfPem(joiner.certificatePem),
      hostFingerprint: _me.fingerprint,
      joinerNonce: nonce,
      hostNonce: joiner.nonce,
    );
    _timer?.cancel();
    _timer = Timer(window, () => _fail('Pairing timed out'));
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
    final accepted = await joiner.decision.future;
    if (accepted && _joiner == joiner) {
      await _paired(
        PairedDevice(
          id: joiner.id,
          name: joiner.name,
          certificatePem: joiner.certificatePem,
          pairedAt: DateTime.now(),
          address: from,
        ),
      );
    }
    return {'accepted': accepted};
  }

  Future<void> _paired(PairedDevice device) async {
    _reset();
    await ref.read(syncServiceProvider).addPaired(device);
    state = PairingDone(device.name);
  }
}
