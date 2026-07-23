import 'package:flutter/services.dart';

import '../platform_services.dart';

/// Switches MovieHub's application-local Windows cursors through the runner.
class WindowsCursorService implements CursorService {
  static const _channel = MethodChannel('moviehub/cursor');

  @override
  bool get isSupported => true;

  @override
  Future<void> setPixelStyleEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setPixelStyleEnabled', enabled);
    } on MissingPluginException {
      // Widget tests do not host the Windows runner.
    }
  }
}
