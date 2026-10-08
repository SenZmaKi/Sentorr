import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/sync/compatibility.dart';

void main() {
  const local = PeerCompatibility.current;
  test('channel does not determine compatibility', () {
    expect(
      local.accepts(const PeerCompatibility(channel: 'nightly').toJson()),
      isTrue,
    );
  });
  test('each shared format must match', () {
    for (final format in local.formats.keys) {
      final declaration = local.toJson();
      declaration['formats'] = {...local.formats, format: 99};
      expect(local.accepts(declaration), isFalse, reason: format);
    }
  });
  test('missing, malformed and unknown metadata fail closed', () {
    for (final value in [null, '', '{', '[]', '{}', 'x' * 2049]) {
      expect(local.acceptsHeader(value), isFalse);
    }
    for (final replacement in <String, Object>{
      'application': 'another-app',
      'validation': 2,
      'protocol': 2,
      'channel': 1,
      'formats': {},
    }.entries) {
      expect(
        local.accepts({...local.toJson(), replacement.key: replacement.value}),
        isFalse,
      );
    }
    expect(local.acceptsHeader(local.header), isTrue);
  });
}
