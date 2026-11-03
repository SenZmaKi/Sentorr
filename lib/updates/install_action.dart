import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import 'controller.dart';
import 'platform_installer.dart';

Future<void> installReadyUpdate(WidgetRef ref) async {
  await ref.read(prepareForUpdateProvider)();
  final result = await ref.read(updatesProvider.notifier).installAndRestart();
  if (result == UpdateInstallDisposition.quitThenRelaunch ||
      result == UpdateInstallDisposition.externalProcessWillTerminate) {
    await ref.read(quitApplicationProvider)();
  }
}
