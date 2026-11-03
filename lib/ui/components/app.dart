import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/notifier.dart';
import '../shared/app_activity.dart';
import '../pages/downloads/downloads_page.dart';
import '../pages/home/home_page.dart';
import '../pages/download_review/review_host.dart';
import '../pages/launch/launch_host.dart';
import '../pages/player/player_host.dart';
import '../pages/search/search_page.dart';
import '../pages/lists/lists_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/title/title_page.dart';
import '../shared/layout/adaptive.dart';
import '../shared/theme/theme.dart';
import 'app_shell.dart';
import 'app_icon_sync.dart';
import 'error_toasts.dart';
import 'notification_taps.dart';
import '../../shared/application_identity.dart';
import '../shared/android_tv.dart';

class SentorrApp extends ConsumerStatefulWidget {
  const SentorrApp({super.key});
  @override
  ConsumerState<SentorrApp> createState() => _SentorrAppState();
}

class _SentorrAppState extends ConsumerState<SentorrApp> {
  bool _isTv = false;

  @override
  void initState() {
    super.initState();
    detectAndroidTv().then((tv) {
      if (mounted) setState(() => _isTv = tv);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: ApplicationIdentity.name,
      debugShowCheckedModeBanner: false,
      theme: buildSentorrTheme(Brightness.light),
      darkTheme: buildSentorrTheme(Brightness.dark),
      themeMode: ref.watch(
        settingsProvider.select((settings) => settings.themeMode),
      ),
      builder: (context, child) => AppActivity(
        child: AdaptiveScope(
          input: _isTv ? InputMode.remote : InputMode.platform,
          child: AppIconSync(
            child: NotificationTaps(child: ErrorToasts(child: child!)),
          ),
        ),
      ),
      home: LaunchHost(
        child: DownloadReviewHost(
          child: PlayerHost(
            child: AppShell(
              pages: const {
                AppDestination.home: HomePage(),
                AppDestination.search: SearchPage(),
                AppDestination.lists: ListsPage(),
                AppDestination.downloads: DownloadsPage(),
                AppDestination.settings: SettingsPage(),
              },
              titlePage: (route) => TitlePage(route: route),
            ),
          ),
        ),
      ),
    );
  }
}
