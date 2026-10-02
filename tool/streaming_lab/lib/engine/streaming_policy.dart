import 'dart:io';

/// Lab defaults selected by the final audit; 0 restores each legacy policy.
abstract final class StreamingPolicy {
  static bool get tcpOnly => Platform.environment['STREAMING_FORCE_TCP'] != '0';
  static bool get narrowUrgent =>
      Platform.environment['STREAMING_NARROW_URGENT'] != '0';
  static bool get bootstrap =>
      Platform.environment['STREAMING_BOOTSTRAP'] != '0';
  static int get networkTimeoutSeconds =>
      (int.tryParse(Platform.environment['STREAMING_NETWORK_TIMEOUT'] ?? '') ??
              60)
          .clamp(1, 120);
}
