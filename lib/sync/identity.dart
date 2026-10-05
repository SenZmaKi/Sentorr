import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';

/// This device as its paired devices know it: a stable id, a name for
/// people, and the TLS certificate its connections are pinned to.
class DeviceIdentity {
  const DeviceIdentity({
    required this.id,
    required this.name,
    required this.certificatePem,
    required this.privateKeyPem,
  });

  /// A new device: a random id and a fresh self-signed P-256 certificate.
  /// Dart's TLS rejects Ed25519 certificates, so this is ECDSA.
  factory DeviceIdentity.generate(String name) {
    final id = _randomHex(16);
    final pair = CryptoUtils.generateEcKeyPair(curve: 'prime256v1');
    final key = pair.privateKey as ECPrivateKey;
    final csr = X509Utils.generateEccCsrPem(
      {'CN': 'Sentorr $id'},
      key,
      pair.publicKey as ECPublicKey,
    );
    return DeviceIdentity(
      id: id,
      name: name,
      // Pinned, never chain-verified, so it may as well outlive the device;
      // kept before 2050, past which validity needs an encoding this
      // generator does not write.
      certificatePem: X509Utils.generateSelfSignedCertificate(
        key,
        csr,
        365 * 20,
        // Unique, so trust stores never take one device's for another's.
        serialNumber: '${BigInt.parse(_randomHex(12), radix: 16)}',
      ),
      privateKeyPem: CryptoUtils.encodeEcPrivateKeyToPem(key),
    );
  }

  final String id, name;
  final String certificatePem, privateKeyPem;

  String get fingerprint => fingerprintOfPem(certificatePem);

  DeviceIdentity named(String name) => DeviceIdentity(
    id: id,
    name: name,
    certificatePem: certificatePem,
    privateKeyPem: privateKeyPem,
  );

  /// Presents this device's certificate, trusting nothing by default.
  SecurityContext context() => SecurityContext(withTrustedRoots: false)
    ..useCertificateChainBytes(utf8.encode(certificatePem))
    ..usePrivateKeyBytes(utf8.encode(privateKeyPem));

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'certificate': certificatePem,
    'privateKey': privateKeyPem,
  };

  static DeviceIdentity? fromJson(Object? json) => switch (json) {
    {
      'id': final String id,
      'name': final String name,
      'certificate': final String certificate,
      'privateKey': final String key,
    } =>
      DeviceIdentity(
        id: id,
        name: name,
        certificatePem: certificate,
        privateKeyPem: key,
      ),
    _ => null,
  };
}

/// What this device calls itself until the viewer renames it.
String defaultDeviceName() {
  if (Platform.isAndroid) return 'Android device';
  if (Platform.isIOS) return 'iPhone';
  final host = Platform.localHostname.split('.').first;
  return host.isEmpty || host == 'localhost'
      ? switch (Platform.operatingSystem) {
          'macos' => 'Mac',
          'windows' => 'Windows PC',
          _ => 'Linux PC',
        }
      : host;
}

/// SHA-256 of a certificate's DER bytes, lowercase hex.
String fingerprintOfDer(List<int> der) => sha256.convert(der).toString();

String fingerprintOfPem(String pem) => fingerprintOfDer(
  base64.decode(
    pem
        .replaceAll(RegExp(r'-----[^-]+-----'), '')
        .replaceAll(RegExp(r'\s'), ''),
  ),
);

String _randomHex(int bytes) {
  final random = Random.secure();
  return List.generate(
    bytes,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
