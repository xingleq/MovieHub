import 'dart:async';

import 'package:flutter/services.dart';

import '../platform_services.dart';

/// Windows workstation session events forwarded from the native runner
/// (WM_WTSSESSION_CHANGE): emits 'lock' when the screen locks and 'unlock'
/// when it unlocks.
class WindowsSessionEvents implements SessionEvents {
  static const _channel = MethodChannel('moviehub/session');

  final _events = StreamController<String>.broadcast();
  var _bound = false;

  @override
  Stream<String> get stream {
    if (!_bound) {
      _bound = true;
      _channel.setMethodCallHandler((call) async {
        _events.add(call.method);
      });
    }
    return _events.stream;
  }
}
