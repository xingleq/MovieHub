#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  static LRESULT CALLBACK FlutterViewWindowProc(HWND window, UINT message,
                                                WPARAM wparam,
                                                LPARAM lparam) noexcept;
  bool ApplyPixelCursor(LPARAM const lparam) noexcept;

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Forwards workstation session events (lock/unlock) to Dart so playback
  // can pause when the screen locks.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      session_channel_;

  // App-local pixel cursors. These never replace the user's system cursors.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      cursor_channel_;
  HCURSOR pixel_pickaxe_cursor_ = nullptr;
  bool pixel_cursor_enabled_ = false;

  // Flutter's render view is a child HWND and owns its cursor messages. Keep a
  // narrow subclass hook so the app cursor is applied after Flutter's handler.
  HWND flutter_view_window_ = nullptr;
  WNDPROC original_flutter_view_proc_ = nullptr;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
