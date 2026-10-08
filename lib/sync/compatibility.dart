import 'dart:convert';

import '../shared/application_identity.dart';
import '../shared/state_formats.dart';

const compatibilityHeader = 'x-sentorr-compatibility';
const compatibilityMessage =
    'These Sentorr builds use incompatible sync formats. Update both apps before exchanging data.';

/// A declaration exchanged over pinned TLS before any user data is sent.
/// Change the affected format when its wire shape or merge semantics change.
/// Channel is informational: stable and nightly with matching formats interoperate.
class PeerCompatibility {
  const PeerCompatibility({
    this.protocol = 1,
    this.formats = const {...StateFormats.versions, 'library': 1, 'media': 1},
    this.channel = ApplicationIdentity.channel,
  });

  static const current = PeerCompatibility();
  final int protocol;
  final Map<String, int> formats;
  final String channel;

  Map<String, dynamic> toJson() => {
    'application': 'sentorr',
    'validation': 1,
    'protocol': protocol,
    'formats': formats,
    'channel': channel,
  };

  String get header => jsonEncode(toJson());

  bool accepts(Object? declaration) {
    if (declaration is! Map ||
        declaration['application'] != 'sentorr' ||
        declaration['validation'] is! int ||
        declaration['validation'] != 1 ||
        declaration['protocol'] is! int ||
        declaration['protocol'] != protocol ||
        declaration['channel'] is! String ||
        declaration['formats'] is! Map) {
      return false;
    }
    final incoming = declaration['formats'] as Map;
    return formats.entries.every(
      (entry) =>
          incoming[entry.key] is int && incoming[entry.key] == entry.value,
    );
  }

  bool acceptsHeader(String? value) {
    if (value == null || value.length > 2048) return false;
    try {
      return accepts(jsonDecode(value));
    } on FormatException {
      return false;
    }
  }
}
