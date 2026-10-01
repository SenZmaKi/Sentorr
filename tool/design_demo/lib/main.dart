import 'package:flutter/material.dart';

import 'ui/demo/demo_shell.dart';
import 'ui/shared/theme/theme.dart';

void main() => runApp(const DesignDemoApp());

class DesignDemoApp extends StatefulWidget {
  const DesignDemoApp({super.key});

  @override
  State<DesignDemoApp> createState() => _DesignDemoAppState();
}

class _DesignDemoAppState extends State<DesignDemoApp> {
  ThemeMode _mode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentorr design demo',
      debugShowCheckedModeBanner: false,
      theme: buildSentorrTheme(Brightness.light),
      darkTheme: buildSentorrTheme(Brightness.dark),
      themeMode: _mode,
      themeAnimationDuration: Motion.panel,
      home: DemoShell(themeMode: _mode, onThemeMode: (m) => setState(() => _mode = m)),
    );
  }
}
