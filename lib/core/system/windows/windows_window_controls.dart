import 'package:flutter/services.dart';

import '../platform_services.dart';

/// Window chrome actions handled by the Windows runner over the
/// `moviehub/session` channel.
class WindowsWindowControls implements WindowControls {
  static const _channel = MethodChannel('moviehub/session');

  @override
  bool get isSupported => true;

  @override
  Future<void> minimize() {
    return _channel.invokeMethod<void>('minimize');
  }

  @override
  Future<void> toggleMaximize() {
    return _channel.invokeMethod<void>('toggleMaximize');
  }

  @override
  Future<void> close() {
    return _channel.invokeMethod<void>('close');
  }
}
