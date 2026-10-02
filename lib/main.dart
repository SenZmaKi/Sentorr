import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'ui/components/app.dart';

Future<void> main() async {
  final runtime = await AppRuntime.initialize();
  runApp(
    UncontrolledProviderScope(
      container: runtime.container,
      child: const SentorrApp(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(runtime.window.reveal());
  });
}
