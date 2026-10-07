import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/sync/file_response.dart';
import 'package:sentorr/sync/identity.dart';
import 'package:sentorr/sync/models.dart';
import 'package:sentorr/sync/pairing_code.dart';
import 'package:sentorr/ui/pages/settings/sections/pairing_sheet.dart';

void main() {
  group('pairing code', () {
    String code({String j = 'j', String h = 'h', String jn = 'a'}) =>
        pairingCode(
          joinerFingerprint: j,
          hostFingerprint: h,
          joinerNonce: jn,
          hostNonce: 'b',
        );

    test('is six digits, the same for the same inputs', () {
      expect(code(), matches(RegExp(r'^\d{6}$')));
      expect(code(), code());
    });

    test('changes with either certificate or nonce', () {
      expect({code(), code(j: 'x'), code(h: 'x'), code(jn: 'x')}, hasLength(4));
    });

    test('commits to a nonce without revealing it', () {
      final nonce = pairingNonce();
      expect(pairingCommitment(nonce), pairingCommitment(nonce));
      expect(pairingCommitment(nonce), isNot(contains(nonce)));
      expect(pairingNonce(), isNot(nonce));
    });
  });

  group('byte ranges', () {
    test('reads the forms players send', () {
      expect(parseRange(null, 100), isNull);
      expect(parseRange('bytes=0-', 100), (start: 0, end: 99));
      expect(parseRange('bytes=10-19', 100), (start: 10, end: 19));
      expect(parseRange('bytes=90-500', 100), (start: 90, end: 99));
      expect(parseRange('bytes=-10', 100), (start: 90, end: 99));
      expect(parseRange('items=0-1', 100), isNull);
    });

    test('refuses ranges past the end', () {
      expect(parseRange('bytes=100-', 100), unsatisfiable);
      expect(parseRange('bytes=5-2', 100), unsatisfiable);
      expect(parseRange('bytes=-0', 100), unsatisfiable);
    });
  });

  test('identities round-trip and keep their fingerprint', () {
    final identity = DeviceIdentity.generate('Laptop');
    final restored = DeviceIdentity.fromJson(identity.toJson())!;
    expect(restored.fingerprint, identity.fingerprint);
    expect(identity.fingerprint, hasLength(64));
    expect(
      DeviceIdentity.generate('Laptop').fingerprint,
      isNot(identity.fingerprint),
    );
  });

  test('paired devices round-trip with their address', () {
    final identity = DeviceIdentity.generate('Phone');
    final device = PairedDevice(
      id: identity.id,
      name: 'Phone',
      certificatePem: identity.certificatePem,
      pairedAt: DateTime(2026, 10, 4),
      address: (host: '192.168.1.4', port: 47615),
    );
    final restored = PairedDevice.fromJson(device.toJson())!;
    expect(restored.address, device.address);
    expect(restored.fingerprint, identity.fingerprint);
  });

  test('typed addresses', () {
    expect(parseDeviceAddress('192.168.1.4'), (
      host: '192.168.1.4',
      port: 47615,
    ));
    expect(parseDeviceAddress(' 10.0.0.2:5000 '), (
      host: '10.0.0.2',
      port: 5000,
    ));
    expect(parseDeviceAddress('[fd00::1]:80'), (host: 'fd00::1', port: 80));
    expect(parseDeviceAddress(''), isNull);
    for (final address in [
      'host:0',
      'host:65536',
      'host:not-a-port',
      'bad host',
      'host/path',
      'user@host',
      'https://host',
    ]) {
      expect(parseDeviceAddress(address), isNull, reason: address);
    }
  });
}
