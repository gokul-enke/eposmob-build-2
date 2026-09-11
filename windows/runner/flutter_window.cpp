#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>
#include <flutter/method_result_functions.h>
#include "app_restart.h"

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr UINT kRestartPreparationFailed = WM_APP + 0x107;
}

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
  restart_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "restart") {
      result->NotImplemented();
    } else if (restart_helper_) {
      result->Error("restart_busy", "Restart is already in progress.");
    } else if (BeginCloudPosRestart(&restart_helper_)) {
      // Keep the request pending so a helper cancellation/failure restores the
      // startup controls. The helper pins this process before requesting exit.
      restart_result_ = std::move(result);
      SetTimer(GetHandle(), 0xC105, 250, nullptr);
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
  KillTimer(GetHandle(), 0xC105);
  if (restart_helper_) CloseHandle(restart_helper_);
  restart_helper_ = nullptr;
  restart_result_.reset();
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
  if (message == CloudPosPrepareRestartMessage()) {
    if (!preparing_restart_ && restart_channel_) {
      preparing_restart_ = true;
      restart_channel_->InvokeMethod("prepareRestart", nullptr,
          std::make_unique<flutter::MethodResultFunctions<flutter::EncodableValue>>(
              [hwnd](const auto*) {
                if (IsWindow(hwnd)) PostMessageW(hwnd, WM_CLOSE, 0, 0);
              },
              [hwnd](const auto&, const auto&, const auto*) {
                if (IsWindow(hwnd)) PostMessageW(hwnd, kRestartPreparationFailed, 0, 0);
              },
              [hwnd]() {
                if (IsWindow(hwnd)) PostMessageW(hwnd, kRestartPreparationFailed, 0, 0);
              }));
    }
    return 0;
  }
  if (message == kRestartPreparationFailed) {
    preparing_restart_ = false;
    return 0;
  }
  if (message == WM_TIMER && wparam == 0xC105 && restart_helper_) {
    if (WaitForSingleObject(restart_helper_, 0) == WAIT_OBJECT_0) {
      KillTimer(hwnd, 0xC105);
      CloseHandle(restart_helper_);
      restart_helper_ = nullptr;
      if (restart_result_) {
        restart_result_->Error("restart_incomplete",
            "CloudPOS was not restarted. Close other copies and try again.");
        restart_result_.reset();
      }
    }
    return 0;
  }
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
