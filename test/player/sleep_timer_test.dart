import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/sleep_timer.dart';

void main() {
  test('player ownership retains timer after settings closes and releases it on exit', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final player = container.listen(sleepTimerProvider, (_, _) {});
    final settings = container.listen(sleepTimerProvider, (_, _) {});
    container.read(sleepTimerProvider.notifier).endOfItem();
    settings.close();
    await container.pump();
    expect(container.read(sleepTimerProvider)?.endOfItem, true);
    player.close();
    await container.pump();
    expect(container.read(sleepTimerProvider), null);
  });
}
