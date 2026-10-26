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
  final Future<AppRuntime> Function({ValueChanged<ThemeMode>? onThemeLoaded})
  initialize;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  AppRuntime? _runtime;
  Object? _error;
  bool _busy = true;
  bool _firstFrameDeferred = true;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.deferFirstFrame();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final runtime = await widget.initialize(
        onThemeLoaded: (mode) {
          if (!mounted) return;
          setState(() => _themeMode = mode);
        },
      );
      if (!mounted) {
        await runtime.dispose();
        return;
      }
      setState(() {
        _runtime = runtime;
        _busy = false;
      });
      _allowFirstFrame();
      _revealAfterRendering(runtime.window);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _busy = false;
      });
      _allowFirstFrame();
      // Even failures before window initialization must be visible.
      _revealAfterRendering(WindowManager.getInstance());
    }
  }

  void _revealAfterRendering(WindowManager window) {
    if (!supportsWindowCustomization) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Every platform submits the app (or its startup error) as its first
      // frame. Desktop also waits for rasterization before showing its window.
      await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
      if (mounted) await window.reveal();
    });
  }

  void _allowFirstFrame() {
    if (!_firstFrameDeferred) return;
    _firstFrameDeferred = false;
    WidgetsBinding.instance.allowFirstFrame();
  }

  @override
  void dispose() {
    _allowFirstFrame();
    super.dispose();
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
      themeMode: _themeMode,
      themeAnimationDuration: Duration.zero,
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
