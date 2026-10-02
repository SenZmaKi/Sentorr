import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/shared/app_lifecycle.dart';
import 'package:sentorr/ui/shared/app_activity.dart';
import 'package:sentorr/ui/shared/window_manager.dart';

class _Lifecycle extends AppLifecycleNotifier {
  @override
  AppLifecycleState build() => AppLifecycleState.resumed;
  void change(AppLifecycleState next) => state = next;
}

class _Animated extends StatefulWidget {
  const _Animated({super.key});
  @override
  State<_Animated> createState() => _AnimatedState();
}

class _AnimatedState extends State<_Animated>
    with SingleTickerProviderStateMixin {
  static int mounts = 0;
  late final clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();
  @override
  void initState() {
    super.initState();
    mounts++;
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: clock,
    builder: (_, _) => Text('${clock.value}'),
  );
}

void main() {
  testWidgets(
    'hide, minimize and background mute tickers without losing state or services',
    (tester) async {
      final window = WindowManager.getInstance();
      final original = window.visible.value;
      window.visible.value = true;
      addTearDown(() => window.visible.value = original);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('window_manager'),
          null,
        ),
      );
      final container = ProviderContainer(
        overrides: [AppLifecycleNotifier.provider.overrideWith(_Lifecycle.new)],
      );
      final key = GlobalKey<_AnimatedState>();
      _AnimatedState.mounts = 0;
      var backgroundTicks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => backgroundTicks++,
      );
      addTearDown(timer.cancel);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: AppActivity(child: _Animated(key: key)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(key.currentState!.clock.value, greaterThan(0));
      for (final pause in <Future<void> Function()>[
        () async => window.onWindowMinimize(),
        window.hide,
        () async => (container.read(
          AppLifecycleNotifier.provider.notifier,
        ) as _Lifecycle).change(AppLifecycleState.hidden),
      ]) {
        await pause();
        await tester.pump();
        final stopped = key.currentState!.clock.value;
        final servicesBefore = backgroundTicks;
        await tester.pump(const Duration(milliseconds: 350));
        expect(key.currentState!.clock.value, stopped);
        expect(backgroundTicks, greaterThan(servicesBefore));
        window.onWindowRestore();
        (container.read(AppLifecycleNotifier.provider.notifier) as _Lifecycle)
            .change(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 135));
        expect(key.currentState!.clock.value, isNot(stopped));
        expect(_AnimatedState.mounts, 1);
      }
      // Losing keyboard focus while still visible does not freeze the window.
      (container.read(AppLifecycleNotifier.provider.notifier) as _Lifecycle)
          .change(AppLifecycleState.inactive);
      await tester.pump();
      expect(container.read(appVisibleProvider), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      timer.cancel();
      container.dispose();
    },
  );
}
