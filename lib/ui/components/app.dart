import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/notifier.dart';
import '../../shared/app_lifecycle.dart';
import '../pages/home/home_page.dart';
import '../pages/launch/launch_host.dart';
import '../pages/player/player_host.dart';
import '../pages/search/search_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/title/title_page.dart';
import '../shared/theme/theme.dart';
import 'app_shell.dart';
import 'desktop_icon_sync.dart';
import 'error_toasts.dart';
import 'notification_taps.dart';

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
      builder: (context, child) => DesktopIconSync(
        child: NotificationTaps(child: ErrorToasts(child: child!)),
      ),
      home: LaunchHost(
        child: PlayerHost(
          child: AppShell(
            pages: const {
              AppDestination.home: HomePage(),
              AppDestination.search: SearchPage(),
              AppDestination.settings: SettingsPage(),
            },
            titlePage: (route) => TitlePage(route: route),
          ),
        ),
      ),
    );
  }
}
