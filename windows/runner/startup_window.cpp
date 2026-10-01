#include "startup_window.h"
#include "resource.h"

namespace {
constexpr wchar_t kClass[] = L"CLOUDPOS_STARTUP_WINDOW";
constexpr UINT kCloseSplash = WM_APP + 21;

// GetDpiForWindow/GetDpiForSystem only exist on Windows 10 1607+. Importing
// them statically stops cloudpos.exe from launching on older Windows, so
// resolve them at runtime and fall back to the screen DC's DPI.
UINT GetLegacyScreenDpi() {
  HDC screen = GetDC(nullptr);
  if (!screen) return 96;
  const int dpi = GetDeviceCaps(screen, LOGPIXELSX);
  ReleaseDC(nullptr, screen);
  return dpi > 0 ? static_cast<UINT>(dpi) : 96;
}

UINT GetSystemDpiCompat() {
  using GetDpiForSystemFn = UINT(WINAPI*)();
  static const auto get_dpi_for_system = reinterpret_cast<GetDpiForSystemFn>(
      GetProcAddress(GetModuleHandleW(L"user32.dll"), "GetDpiForSystem"));
  return get_dpi_for_system ? get_dpi_for_system() : GetLegacyScreenDpi();
}

UINT GetWindowDpiCompat(HWND window) {
  using GetDpiForWindowFn = UINT(WINAPI*)(HWND);
  static const auto get_dpi_for_window = reinterpret_cast<GetDpiForWindowFn>(
      GetProcAddress(GetModuleHandleW(L"user32.dll"), "GetDpiForWindow"));
  if (get_dpi_for_window) {
    const UINT dpi = get_dpi_for_window(window);
    if (dpi > 0) return dpi;
  }
  return GetLegacyScreenDpi();
}
}

StartupWindow::StartupWindow() : runner_thread_(GetCurrentThreadId()) {
  // Ensure WM_QUIT can be posted to the runner even during engine creation.
  MSG message;
  PeekMessage(&message, nullptr, WM_USER, WM_USER, PM_NOREMOVE);
  ready_ = CreateEvent(nullptr, TRUE, FALSE, nullptr);
  if (!ready_) return;
  thread_ = std::thread(&StartupWindow::Run, this);
  WaitForSingleObject(ready_, INFINITE);
}

StartupWindow::~StartupWindow() {
  Close();
  if (ready_) CloseHandle(ready_);
}

void StartupWindow::Close() {
  HWND window = window_.load();
  if (window) PostMessage(window, kCloseSplash, 0, 0);
  if (thread_.joinable()) thread_.join();
}

void StartupWindow::Run() {
  WNDCLASSW wc{};
  wc.lpfnWndProc = WindowProc;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.lpszClassName = kClass;
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  wc.hIcon = LoadIcon(wc.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
  wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
  RegisterClassW(&wc);
  const UINT dpi = GetSystemDpiCompat();
  const int width = MulDiv(480, static_cast<int>(dpi), 96);
  const int height = MulDiv(300, static_cast<int>(dpi), 96);
  HWND window = CreateWindowW(kClass, L"CLOUDPOS", WS_OVERLAPPED | WS_CAPTION |
      WS_SYSMENU | WS_MINIMIZEBOX, (GetSystemMetrics(SM_CXSCREEN) - width) / 2,
      (GetSystemMetrics(SM_CYSCREEN) - height) / 2, width, height,
      nullptr, nullptr, wc.hInstance, this);
  window_.store(window);
  if (window) {
    SetPropW(window, L"CLOUDPOS.ApplicationWindow", reinterpret_cast<HANDLE>(1));
    ShowWindow(window, SW_SHOWNORMAL);
    // A launcher can supply SW_HIDE in STARTUPINFO, overriding the first
    // ShowWindow call. CloudPOS always acknowledges an interactive launch.
    SetWindowPos(window, HWND_TOP, 0, 0, 0, 0,
        SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
    UpdateWindow(window);
  }
  SetEvent(ready_);
  if (window) {
    MSG message;
    while (GetMessage(&message, nullptr, 0, 0) > 0) {
      TranslateMessage(&message);
      DispatchMessage(&message);
    }
  }
  window_.store(nullptr);
}

LRESULT CALLBACK StartupWindow::WindowProc(HWND window, UINT message,
                                         WPARAM wparam, LPARAM lparam) {
  auto* self = reinterpret_cast<StartupWindow*>(GetWindowLongPtr(window, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    self = static_cast<StartupWindow*>(reinterpret_cast<CREATESTRUCT*>(lparam)->lpCreateParams);
    SetWindowLongPtr(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
  }
  switch (message) {
    case WM_PAINT: {
      PAINTSTRUCT paint;
      HDC dc = BeginPaint(window, &paint);
      RECT rect;
      GetClientRect(window, &rect);
      SetBkMode(dc, TRANSPARENT);
      const int dpi = static_cast<int>(GetWindowDpiCompat(window));
      const int logo_size = MulDiv(112, dpi, 96);
      HICON logo = static_cast<HICON>(LoadImageW(GetModuleHandle(nullptr),
          MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON, logo_size, logo_size, 0));
      if (logo) {
        DrawIconEx(dc, (rect.right - logo_size) / 2, MulDiv(16, dpi, 96),
            logo, logo_size, logo_size, 0, nullptr, DI_NORMAL);
        DestroyIcon(logo);
      }
      rect.top = MulDiv(148, dpi, 96);
      HFONT font = CreateFontW(-MulDiv(22, dpi, 96), 0, 0, 0, FW_SEMIBOLD,
          FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
          CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
      HGDIOBJ previous = SelectObject(dc, font);
      SetTextColor(dc, RGB(25, 103, 210));
      const wchar_t* text = self && self->cancelled() ? L"Closing CloudPOS..."
          : L"Opening CloudPOS...\nPlease wait while the app starts.";
      DrawTextW(dc, text, -1, &rect, DT_CENTER | DT_WORDBREAK);
      SelectObject(dc, previous);
      DeleteObject(font);
      EndPaint(window, &paint);
      return 0;
    }
    case WM_CLOSE:
      if (self) {
        self->cancelled_.store(true);
        PostThreadMessage(self->runner_thread_, WM_QUIT, 0, 0);
        InvalidateRect(window, nullptr, TRUE);
      }
      return 0;
    case kCloseSplash:
      DestroyWindow(window);
      return 0;
    case WM_DESTROY:
      RemovePropW(window, L"CLOUDPOS.ApplicationWindow");
      PostQuitMessage(0);
      return 0;
    default:
      return DefWindowProc(window, message, wparam, lparam);
  }
}
