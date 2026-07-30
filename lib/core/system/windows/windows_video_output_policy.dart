import '../platform_services.dart';

/// Uses media_kit's CPU texture path on Windows.
///
/// Its ANGLE/Direct3D GPU texture can become tied to the laptop display
/// adapter. Moving the Flutter window to a TV driven by another adapter then
/// leaves audio working while the video texture is black.
class WindowsVideoOutputPolicy implements VideoOutputPolicy {
  const WindowsVideoOutputPolicy();

  @override
  bool get enableHardwareAcceleration => false;
}
