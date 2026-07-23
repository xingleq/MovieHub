#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <wtsapi32.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <optional>
#include <string_view>

#include "flutter/generated_plugin_registrant.h"

#pragma comment(lib, "wtsapi32.lib")

namespace {

constexpr wchar_t kFlutterWindowProperty[] = L"MovieHub.FlutterWindow";

constexpr int kPatternSize = 16;
constexpr int kPixelScale = 2;
constexpr int kCursorSize = kPatternSize * kPixelScale;

using CursorPattern = std::array<std::string_view, kPatternSize>;

constexpr CursorPattern kPickaxePattern = {
    "....OOOOOOOO....", "...OCCCCCCCCO...", "..OCCCCCCCCCCO..",
    ".OCCCCOOOOCCCCO.", "OCCCCO....OCCCCO", ".OOOO......OOOO.",
    "........OO......", ".......OHHO.....", "......OHHHO.....",
    ".....OHHHO......", "....OHHHO.......", "...OHHHO........",
    "..OHHHO.........", ".OHHHO..........", "OHHHO...........",
    ".OOO............",
};

HCURSOR CreatePixelCursor(const CursorPattern& pattern, DWORD hotspot_x,
                          DWORD hotspot_y) {
  BITMAPV5HEADER header = {};
  header.bV5Size = sizeof(BITMAPV5HEADER);
  header.bV5Width = kCursorSize;
  header.bV5Height = -kCursorSize;
  header.bV5Planes = 1;
  header.bV5BitCount = 32;
  header.bV5Compression = BI_BITFIELDS;
  header.bV5RedMask = 0x00FF0000;
  header.bV5GreenMask = 0x0000FF00;
  header.bV5BlueMask = 0x000000FF;
  header.bV5AlphaMask = 0xFF000000;

  void* bitmap_bits = nullptr;
  HDC screen = GetDC(nullptr);
  HBITMAP color_bitmap = CreateDIBSection(
      screen, reinterpret_cast<BITMAPINFO*>(&header), DIB_RGB_COLORS,
      &bitmap_bits, nullptr, 0);
  ReleaseDC(nullptr, screen);
  if (!color_bitmap || !bitmap_bits) {
    return nullptr;
  }

  auto* pixels = static_cast<std::uint32_t*>(bitmap_bits);
  std::fill_n(pixels, kCursorSize * kCursorSize, 0x00000000);
  for (int source_y = 0; source_y < kPatternSize; ++source_y) {
    for (int source_x = 0; source_x < kPatternSize; ++source_x) {
      const char cell = pattern[source_y][source_x];
      if (cell == '.') {
        continue;
      }
      std::uint32_t color = 0xFF55E6FF;
      if (cell == 'O') {
        color = 0xFF102A56;
      } else if (cell == 'H') {
        color = 0xFF9A6538;
      }
      for (int offset_y = 0; offset_y < kPixelScale; ++offset_y) {
        for (int offset_x = 0; offset_x < kPixelScale; ++offset_x) {
          const int x = source_x * kPixelScale + offset_x;
          const int y = source_y * kPixelScale + offset_y;
          pixels[y * kCursorSize + x] = color;
        }
      }
    }
  }

  std::array<std::uint8_t, kCursorSize * kCursorSize / 8> mask_bits = {};
  HBITMAP mask_bitmap =
      CreateBitmap(kCursorSize, kCursorSize, 1, 1, mask_bits.data());
  if (!mask_bitmap) {
    DeleteObject(color_bitmap);
    return nullptr;
  }

  ICONINFO cursor_info = {};
  cursor_info.fIcon = FALSE;
  cursor_info.xHotspot = hotspot_x;
  cursor_info.yHotspot = hotspot_y;
  cursor_info.hbmMask = mask_bitmap;
  cursor_info.hbmColor = color_bitmap;
  HCURSOR cursor = static_cast<HCURSOR>(CreateIconIndirect(&cursor_info));
  DeleteObject(mask_bitmap);
  DeleteObject(color_bitmap);
  return cursor;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  flutter_view_window_ = flutter_controller_->view()->GetNativeWindow();
  SetChildContent(flutter_view_window_);

  // WM_SETCURSOR is handled by Flutter's child HWND rather than by the runner
  // window. Subclass it so the pixel cursor wins after Flutter selects its
  // system cursor; otherwise the next pointer event immediately resets it.
  SetPropW(flutter_view_window_, kFlutterWindowProperty, this);
  original_flutter_view_proc_ = reinterpret_cast<WNDPROC>(SetWindowLongPtrW(
      flutter_view_window_, GWLP_WNDPROC,
      reinterpret_cast<LONG_PTR>(&FlutterWindow::FlutterViewWindowProc)));

  session_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "moviehub/session",
          &flutter::StandardMethodCodec::GetInstance());
  session_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& method = call.method_name();
        if (method == "minimize") {
          ShowWindow(GetHandle(), SW_MINIMIZE);
          result->Success();
          return;
        }
        if (method == "toggleMaximize") {
          ShowWindow(GetHandle(),
                     IsZoomed(GetHandle()) ? SW_RESTORE : SW_MAXIMIZE);
          result->Success();
          return;
        }
        if (method == "close") {
          PostMessage(GetHandle(), WM_CLOSE, 0, 0);
          result->Success();
          return;
        }
        result->NotImplemented();
      });

  pixel_pickaxe_cursor_ = CreatePixelCursor(kPickaxePattern, 2, 2);
  cursor_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "moviehub/cursor",
          &flutter::StandardMethodCodec::GetInstance());
  cursor_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "setPixelStyleEnabled") {
          result->NotImplemented();
          return;
        }
        const auto* enabled = std::get_if<bool>(call.arguments());
        if (!enabled) {
          result->Error("invalid_argument", "Expected a boolean value.");
          return;
        }
        pixel_cursor_enabled_ = *enabled;
        SetCursor(pixel_cursor_enabled_ && pixel_pickaxe_cursor_
                      ? pixel_pickaxe_cursor_
                      : LoadCursor(nullptr, IDC_ARROW));
        result->Success();
      });

  // Receive WM_WTSSESSION_CHANGE for this session (screen lock/unlock).
  WTSRegisterSessionNotification(GetHandle(), NOTIFY_FOR_THIS_SESSION);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  WTSUnRegisterSessionNotification(GetHandle());
  if (flutter_view_window_) {
    if (original_flutter_view_proc_ && IsWindow(flutter_view_window_)) {
      SetWindowLongPtrW(
          flutter_view_window_, GWLP_WNDPROC,
          reinterpret_cast<LONG_PTR>(original_flutter_view_proc_));
    }
    RemovePropW(flutter_view_window_, kFlutterWindowProperty);
    flutter_view_window_ = nullptr;
    original_flutter_view_proc_ = nullptr;
  }
  session_channel_ = nullptr;
  cursor_channel_ = nullptr;
  if (pixel_pickaxe_cursor_) {
    DestroyCursor(pixel_pickaxe_cursor_);
    pixel_pickaxe_cursor_ = nullptr;
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      if (message == WM_SETCURSOR && ApplyPixelCursor(lparam)) {
        return TRUE;
      }
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_WTSSESSION_CHANGE:
      if (session_channel_) {
        if (wparam == WTS_SESSION_LOCK) {
          session_channel_->InvokeMethod("lock", nullptr);
        } else if (wparam == WTS_SESSION_UNLOCK) {
          session_channel_->InvokeMethod("unlock", nullptr);
        }
      }
      break;
  }

  if (message == WM_SETCURSOR && ApplyPixelCursor(lparam)) {
    return TRUE;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

bool FlutterWindow::ApplyPixelCursor(LPARAM const lparam) noexcept {
  if (!pixel_cursor_enabled_ || LOWORD(lparam) != HTCLIENT ||
      !pixel_pickaxe_cursor_) {
    return false;
  }
  SetCursor(pixel_pickaxe_cursor_);
  return true;
}

LRESULT CALLBACK FlutterWindow::FlutterViewWindowProc(
    HWND window, UINT const message, WPARAM const wparam,
    LPARAM const lparam) noexcept {
  auto* owner = reinterpret_cast<FlutterWindow*>(
      GetPropW(window, kFlutterWindowProperty));
  if (!owner || !owner->original_flutter_view_proc_) {
    return DefWindowProcW(window, message, wparam, lparam);
  }

  const LRESULT result = CallWindowProcW(owner->original_flutter_view_proc_,
                                         window, message, wparam, lparam);
  if (message == WM_SETCURSOR && owner->ApplyPixelCursor(lparam)) {
    return TRUE;
  }
  return result;
}
