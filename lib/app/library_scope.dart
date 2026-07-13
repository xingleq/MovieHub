import 'package:flutter/widgets.dart';

import 'library_controller.dart';

/// Exposes the [LibraryController] to the widget tree.
///
/// Rebuilds are driven explicitly by the shell's ListenableBuilder. Keeping
/// this as a plain InheritedWidget avoids InheritedNotifier dependency cleanup
/// assertions during window teardown and route transitions.
class LibraryScope extends InheritedWidget {
  const LibraryScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final LibraryController controller;

  /// Reads the controller and subscribes the calling context to its changes.
  static LibraryController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LibraryScope>();
    assert(scope != null, 'LibraryScope not found in widget tree');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(LibraryScope oldWidget) {
    return oldWidget.controller != controller;
  }
}
