import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/queue_builder.dart';
import 'package:sentorr/player/session.dart';
import 'package:sentorr/ui/shared/player_view.dart';

void main() {
  test('closing a mini player preserves its chrome until the next session', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(playerViewProvider, (_, _) {});
    addTearDown(subscription.close);
    final session = container.read(playerSessionProvider.notifier);
    final view = container.read(playerViewProvider.notifier);
    final title = ImdbTitle(id: 'tt1', title: 'Movie');
    final queue = PlayQueue(
      items: [PlaybackItem(title: title)],
      index: 0,
      kind: QueueKind.recommendations,
    );

    session.play(PlayTitle(title), queue: queue);
    view.minimize();
    expect(container.read(playerViewProvider), PlayerView.mini);

    session.close();
    expect(container.read(playerSessionProvider), isNull);
    // PlayerPage stays mounted during PlayerHost's outgoing fade and
    // watches this value to decide whether to show full controls.
    expect(container.read(playerViewProvider), PlayerView.mini);

    session.play(PlayTitle(title), queue: queue);
    expect(container.read(playerViewProvider), PlayerView.full);
  });
}
