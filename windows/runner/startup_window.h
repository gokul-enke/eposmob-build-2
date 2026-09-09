#ifndef RUNNER_STARTUP_WINDOW_H_
#define RUNNER_STARTUP_WINDOW_H_

#include <windows.h>
#include <atomic>
#include <thread>

// Owns a small native UI thread so engine/plugin startup cannot hide the
// launch acknowledgment or stop its window from processing messages.
class StartupWindow {
 public:
  StartupWindow();
  ~StartupWindow();
  void Close();
  bool cancelled() const { return cancelled_.load(); }

 private:
  void Run();
  static LRESULT CALLBACK WindowProc(HWND, UINT, WPARAM, LPARAM);
  std::thread thread_;
  HANDLE ready_ = nullptr;
  std::atomic<HWND> window_{nullptr};
  std::atomic<bool> cancelled_{false};
  DWORD runner_thread_ = 0;
};

#endif
