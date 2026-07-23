import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app_shell.dart';
import 'app/library_controller.dart';
import 'app/settings_controller.dart';
import 'theme/app_theme.dart';
import 'ui/widgets/screen_time_overlay.dart';

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
  late final SettingsController _settings;
  late final LibraryController _library;

  @override
  void initState() {
    super.initState();
    _settings = SettingsController();
    _library = LibraryController(settings: _settings);
  }

  @override
  void dispose() {
    _library.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only settings drive MaterialApp (theme mode); library churn — scans,
    // matches, progress saves — must not rebuild from the root.
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'MovieHub',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: _themeModeOf(_settings.themeMode),
          builder: (context, child) {
            return ListenableBuilder(
              listenable: _settings,
              builder: (context, _) {
                return Stack(
                  children: [
                    ?child,
                    ScreenTimeOverlay(settings: _settings),
                  ],
                );
              },
            );
          },
          home: AppShell(library: _library, settings: _settings),
        );
      },
    );
  }

  static ThemeMode _themeModeOf(String value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }
}
