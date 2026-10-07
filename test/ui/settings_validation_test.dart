import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/settings/settings_validation.dart';

void main() {
  test('proxy host accepts hostnames and IPv4 and IPv6 addresses', () {
    for (final host in ['proxy.local', '127.0.0.1', '::1', '[fd00::1]']) {
      expect(validateProxyHost(host), isNull, reason: host);
    }
  });

  test('proxy host explains invalid addresses', () {
    for (final host in [
      '',
      'bad host',
      'https://proxy.local',
      'proxy.local:80',
      'user@proxy.local',
      'proxy.local/path',
      'proxy.local?query',
    ]) {
      expect(validateProxyHost(host), isNotNull, reason: host);
    }
  });

  test('device name must not be blank', () {
    expect(validateDeviceName('   '), 'Enter a device name.');
    expect(validateDeviceName('Living room'), isNull);
  });
}
