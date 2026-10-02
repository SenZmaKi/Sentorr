import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/desktop_icon_controller.dart';
import '../shared/theme/theme.dart';

/// Reads MaterialApp's resolved theme, including live system brightness changes.
class DesktopIconSync extends ConsumerStatefulWidget {
  const DesktopIconSync({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DesktopIconSync> createState() => _DesktopIconSyncState();
}

class _DesktopIconSyncState extends ConsumerState<DesktopIconSync> {
  String? _variant;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brand = context.brand;
    if (_variant == brand.variant) return;
    _variant = brand.variant;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _variant != brand.variant) return;
      unawaited(ref.read(desktopIconControllerProvider).update(brand));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
