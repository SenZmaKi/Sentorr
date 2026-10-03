import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:sentorr/shared/signed_envelope.dart';
import 'package:test/test.dart';

void main() {
  test(
    'verifies exact bytes and rejects tampering or a different trust key',
    () async {
      final algorithm = Ed25519();
      final pair = await algorithm.newKeyPair();
      final payload = utf8.encode('{"version":1}');
      final signed = await algorithm.sign(payload, keyPair: pair);
      final public = base64.encode((await pair.extractPublicKey()).bytes);
      String envelope(List<int> bytes) => jsonEncode({
        'payload': base64UrlEncode(bytes),
        'signature': base64.encode(signed.bytes),
      });
      expect(
        await decodeSignedJsonEnvelope(
          envelope(payload),
          publicKeyBase64: public,
        ),
        {'version': 1},
      );
      await expectLater(
        decodeSignedJsonEnvelope(
          envelope(utf8.encode('{"version":2}')),
          publicKeyBase64: public,
        ),
        throwsFormatException,
      );
      final other = await algorithm.newKeyPair();
      await expectLater(
        decodeSignedJsonEnvelope(
          envelope(payload),
          publicKeyBase64: base64.encode(
            (await other.extractPublicKey()).bytes,
          ),
        ),
        throwsFormatException,
      );
    },
  );
}
