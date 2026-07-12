import 'package:flutter/widgets.dart';

import 'library_controller.dart';

/// Exposes the [LibraryController] to the widget tree.
class LibraryScope extends InheritedNotifier<LibraryController> {
  const LibraryScope({
    super.key,
    required LibraryController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Reads the controller and subscribes the calling context to its changes.
  static LibraryController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LibraryScope>();
    assert(scope != null, 'LibraryScope not found in widget tree');
    return scope!.notifier!;
  }
}
