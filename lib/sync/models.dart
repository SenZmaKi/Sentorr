import 'identity.dart';

/// Where a device listens; v6 hosts are kept bare, as [Uri] wants them.
typedef DeviceAddress = ({String host, int port});

/// A device the viewer paired with. Its connections must present
/// [certificatePem]; nothing else about it is trusted.
class PairedDevice {
  const PairedDevice({
    required this.id,
    required this.name,
    required this.certificatePem,
    required this.pairedAt,
    this.address,
    this.syncedAt,
  });

  final String id, name, certificatePem;
  final DateTime pairedAt;

  /// Where it was last reached, tried when discovery cannot find it.
  final DeviceAddress? address;

  /// When the two last matched.
  final DateTime? syncedAt;

  String get fingerprint => fingerprintOfPem(certificatePem);

  PairedDevice copyWith({
    String? name,
    DeviceAddress? address,
    DateTime? syncedAt,
  }) => PairedDevice(
    id: id,
    name: name ?? this.name,
    certificatePem: certificatePem,
    pairedAt: pairedAt,
    address: address ?? this.address,
    syncedAt: syncedAt ?? this.syncedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'certificate': certificatePem,
    'pairedAt': pairedAt.toUtc().toIso8601String(),
    if (address case final a?) 'address': {'host': a.host, 'port': a.port},
    if (syncedAt case final s?) 'syncedAt': s.toUtc().toIso8601String(),
  };

  /// Null when [json] is not a device, so one bad record is skipped.
  static PairedDevice? fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'name': final String name,
      'certificate': final String certificate,
      'pairedAt': final String pairedAt,
    }) {
      final at = DateTime.tryParse(pairedAt);
      if (at == null) return null;
      final address = switch (json['address']) {
        {'host': final String host, 'port': final int port} => (
          host: host,
          port: port,
        ),
        _ => null,
      };
      return PairedDevice(
        id: id,
        name: name,
        certificatePem: certificate,
        pairedAt: at.toLocal(),
        address: address,
        syncedAt: DateTime.tryParse(json['syncedAt'] as String? ?? '')
            ?.toLocal(),
      );
    }
    return null;
  }
}

/// A Sentorr found on the local network, paired or not.
class NearbyDevice {
  const NearbyDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.pairing,
  });

  final String id, name;
  final DeviceAddress address;

  /// Open for pairing right now.
  final bool pairing;
}
