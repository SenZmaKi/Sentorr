import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/shared/title_format.dart';

void main() {
  test('counts keep one decimal only below ten', () {
    expect(compactCount(940), '940');
    expect(compactCount(78329), '78K');
    expect(compactCount(2684314), '2.7M');
    expect(compactCount(3000000), '3M');
  });

  test('player clocks and stamps', () {
    expect(clockLabel(const Duration(minutes: 48, seconds: 12)), '48:12');
    expect(clockLabel(const Duration(hours: 1, minutes: 34)), '1:34:00');
    expect(stampLabel(const Duration(minutes: 52)), '52m');
    expect(episodeCode(4, 8), 'S4 E8');
  });
}
