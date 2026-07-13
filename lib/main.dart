import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app_shell.dart';
import 'app/library_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MovieHubApp());
}

class MovieHubApp extends StatefulWidget {
  const MovieHubApp({super.key});

  @override
  State<MovieHubApp> createState() => _MovieHubAppState();
}

class _MovieHubAppState extends State<MovieHubApp> {
  late final LibraryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LibraryController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'MovieHub',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: _themeModeOf(_controller.themeMode),
          home: AppShell(controller: _controller),
        );
      },
    );
  }

  static ThemeMode _themeModeOf(String value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }
}
