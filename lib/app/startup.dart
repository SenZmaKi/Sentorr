import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/components/app.dart';
import '../ui/shared/theme/theme.dart';
import '../ui/shared/window_manager.dart';
import 'bootstrap.dart';

/// Keeps startup failures visible and allows retry after failed resources unwind.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key, this.initialize = AppRuntime.initialize});
  final Future<AppRuntime> Function() initialize;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  AppRuntime? _runtime;
  Object? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final runtime = await widget.initialize();
      if (!mounted) {
        await runtime.dispose();
        return;
      }
      setState(() {
        _runtime = runtime;
        _busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(runtime.window.reveal());
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _busy = false;
      });
      // Even failures before window initialization must be visible.
      unawaited(WindowManager.getInstance().reveal());
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _runtime;
    if (runtime != null) {
      return UncontrolledProviderScope(
        container: runtime.container,
        child: const SentorrApp(),
      );
    }
    return MaterialApp(
      theme: buildSentorrTheme(Brightness.light),
      darkTheme: buildSentorrTheme(Brightness.dark),
      home: Scaffold(
        body: Center(
          child: _busy
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Sentorr could not start'),
                    Text('$_error', textAlign: TextAlign.center),
                    TextButton(onPressed: _start, child: const Text('Retry')),
                  ],
                ),
        ),
      ),
    );
  }
}
