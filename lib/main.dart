import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app_shell.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MovieHubApp());
}

class MovieHubApp extends StatelessWidget {
  const MovieHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MovieHub',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      home: const AppShell(),
    );
  }
}
