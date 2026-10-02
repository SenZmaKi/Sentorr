import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/notifier.dart';
import '../../shared/app_lifecycle.dart';
import '../pages/home/home_page.dart';
import '../pages/search/search_page.dart';
import '../pages/settings_page.dart';
import '../shared/theme/theme.dart';
import 'app_shell.dart';

class SentorrApp extends ConsumerWidget {
  const SentorrApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(AppLifecycleNotifier.provider);
    return MaterialApp(
      title: 'Sentorr',
      debugShowCheckedModeBanner: false,
      theme: buildSentorrTheme(Brightness.light),
      darkTheme: buildSentorrTheme(Brightness.dark),
      themeMode: ref.watch(
        settingsProvider.select((settings) => settings.themeMode),
      ),
      home: const AppShell(
        pages: {
          AppDestination.home: HomePage(),
          AppDestination.search: SearchPage(),
          AppDestination.settings: SettingsPage(),
        },
      ),
    );
  }
}
