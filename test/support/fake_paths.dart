import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/shared/persistence/app_paths.dart';

Future<AppPaths> temporaryAppPaths() async {
  final root = await Directory.systemTemp.createTemp('sentorr-widget-');
  addTearDown(() => root.delete(recursive: true));
  return AppPaths.initialize(rootDirectory: root);
}
