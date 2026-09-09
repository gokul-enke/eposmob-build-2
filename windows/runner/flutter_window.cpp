#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>
#include "app_restart.h"

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project, StartupWindow* startup)
    : project_(project), startup_(startup) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }
  SetPropW(GetHandle(), L"CLOUDPOS.ApplicationWindow", reinterpret_cast<HANDLE>(1));

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
  restart_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "cloudpos/lifecycle",
      &flutter::StandardMethodCodec::GetInstance());
  restart_channel_->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() != "restart") {
      result->NotImplemented();
    } else if (BeginCloudPosRestart()) {
      result->Success();
    } else {
      result->Error("restart_failed", "Windows couldn't start the restart helper.");
    }
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    SetPropW(GetHandle(), L"CLOUDPOS.ReadyWindow", reinterpret_cast<HANDLE>(1));
    if (!startup_ || !startup_->cancelled()) this->Show();
    if (startup_) startup_->Close();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemovePropW(GetHandle(), L"CLOUDPOS.ReadyWindow");
  RemovePropW(GetHandle(), L"CLOUDPOS.ApplicationWindow");
  restart_channel_.reset();
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
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
