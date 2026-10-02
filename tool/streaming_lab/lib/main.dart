import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import 'ui/lab_page.dart';
import 'runtime/playback_smoke.dart';
import 'runtime/performance_audit.dart';

void main(List<String> arguments) {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(
    MaterialApp(
      title: 'Sentorr Streaming Lab',
      debugShowCheckedModeBanner: false,
      theme: buildSentorrTheme(Brightness.light),
      darkTheme: buildSentorrTheme(Brightness.dark),
      home: LabPage(
        smoke: arguments.contains('--audit')
            ? (lab) => performanceAudit(lab, arguments)
            : arguments.contains('--smoke-test')
            ? (lab) => playbackSmoke(lab, arguments)
            : null,
      ),
    ),
  );
}
