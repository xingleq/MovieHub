import 'package:flutter/widgets.dart';

import 'settings_controller.dart';

/// Exposes the [SettingsController] to the widget tree.
///
/// Rebuilds are driven explicitly by the shell's ListenableBuilder. Keeping
/// this as a plain InheritedWidget avoids InheritedNotifier dependency cleanup
/// assertions during window teardown and route transitions.
class SettingsScope extends InheritedWidget {
  const SettingsScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final SettingsController controller;

  /// Reads the controller and subscribes the calling context to its changes.
  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope not found in widget tree');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(SettingsScope oldWidget) {
    return oldWidget.controller != controller;
  }
}
