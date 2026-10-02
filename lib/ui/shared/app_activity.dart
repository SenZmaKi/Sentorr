import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/app_lifecycle.dart';
import 'window_manager.dart';

/// A visible but unfocused desktop window can still animate. Hidden/minimized
/// windows and background mobile apps keep their services, but mute UI tickers.
final appVisibleProvider = Provider<bool>((ref) {
  final lifecycle = ref.watch(AppLifecycleNotifier.provider);
  final visible = WindowManager.getInstance().visible;
  void changed() => ref.invalidateSelf();
  visible.addListener(changed);
  ref.onDispose(() => visible.removeListener(changed));
  return visible.value &&
      (lifecycle == AppLifecycleState.resumed ||
          lifecycle == AppLifecycleState.inactive);
});

class AppActivity extends ConsumerWidget {
  const AppActivity({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      TickerMode(enabled: ref.watch(appVisibleProvider), child: child);
}
