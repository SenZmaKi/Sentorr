import 'package:flutter/widgets.dart';

import 'app/startup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppStartup());
}
