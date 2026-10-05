import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Numeric-comparison pairing, as in Bluetooth: both devices derive the same
/// six digits from both certificates and both nonces, and the viewer checks
/// they match. The joiner commits to its nonce before the host reveals its
/// own, so someone in the middle gets one blind guess in a million.

/// A fresh random nonce, base64.
String pairingNonce() {
  final random = Random.secure();
  return base64.encode(
    Uint8List.fromList(List.generate(32, (_) => random.nextInt(256))),
  );
}

/// What the joiner sends first, binding it to [nonce] unseen.
String pairingCommitment(String nonce) =>
    sha256.convert(utf8.encode('sentorr-commit:$nonce')).toString();

/// The six digits both devices show.
String pairingCode({
  required String joinerFingerprint,
  required String hostFingerprint,
  required String joinerNonce,
  required String hostNonce,
}) {
  final digest = sha256.convert(
    utf8.encode(
      'sentorr-pair:$joinerFingerprint:$hostFingerprint:'
      '$joinerNonce:$hostNonce',
    ),
  );
  final value = ByteData.sublistView(Uint8List.fromList(digest.bytes))
      .getUint32(0);
  return (value % 1000000).toString().padLeft(6, '0');
}
