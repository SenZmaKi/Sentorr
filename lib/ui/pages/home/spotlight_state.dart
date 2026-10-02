import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which featured title the spotlight shows; shared by the hero and the
/// ambient artwork behind the page.
final spotlightIndexProvider = NotifierProvider<SpotlightIndex, int>(
  SpotlightIndex.new,
);

class SpotlightIndex extends Notifier<int> {
  @override
  int build() => 0;

  void show(int index) => state = index;
}
