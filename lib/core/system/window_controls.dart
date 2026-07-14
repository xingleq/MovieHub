import 'package:flutter/services.dart';

class WindowControls {
  WindowControls._();

  static const _channel = MethodChannel('moviehub/session');

  static Future<void> minimize() {
    return _channel.invokeMethod<void>('minimize');
  }

  static Future<void> toggleMaximize() {
    return _channel.invokeMethod<void>('toggleMaximize');
  }

  static Future<void> close() {
    return _channel.invokeMethod<void>('close');
  }
}
