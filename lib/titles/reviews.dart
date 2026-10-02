import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether reviews that reveal the plot are shown. Off by default; holds
/// for the session across every title.
final showSpoilersProvider = NotifierProvider<ShowSpoilersNotifier, bool>(
  ShowSpoilersNotifier.new,
);

class ShowSpoilersNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool show) => state = show;
}
