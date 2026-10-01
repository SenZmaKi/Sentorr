import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'player_page.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(CodecLab(smoke: args.contains('--smoke-test')));
}

class CodecLab extends StatelessWidget {
  final bool smoke;
  const CodecLab({super.key, this.smoke = false});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sentorr Codec Lab',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xff74dec7),
      scaffoldBackgroundColor: const Color(0xff10151c),
      useMaterial3: true,
    ),
    home: PlayerPage(smoke: smoke),
  );
}
