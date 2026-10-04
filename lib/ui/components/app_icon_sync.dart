import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/notifier.dart';
import '../shared/app_icon_controller.dart';
import '../shared/theme/theme.dart';

/// Reads MaterialApp's resolved theme, including live system brightness changes,
/// and passes the chosen theme mode on for the next launch's splash.
class AppIconSync extends ConsumerStatefulWidget {
  const AppIconSync({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppIconSync> createState() => _AppIconSyncState();
}

class _AppIconSyncState extends ConsumerState<AppIconSync> {
  String? _variant;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      settingsProvider.select((settings) => settings.themeMode),
      (_, mode) =>
          unawaited(ref.read(appIconControllerProvider).updateSplash(mode)),
      fireImmediately: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brand = context.brand;
    if (_variant == brand.variant) return;
    _variant = brand.variant;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _variant != brand.variant) return;
      unawaited(ref.read(appIconControllerProvider).update(brand));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
