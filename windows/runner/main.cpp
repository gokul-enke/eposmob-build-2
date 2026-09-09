#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shellapi.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Session-scoped, so two Windows users on the same machine (or two RDP
// sessions) can still each run their own till.
constexpr wchar_t kSingleInstanceMutexName[] =
    L"Local\\CLOUDPOS.EposMob.SingleInstance";

// The window class every Flutter Windows runner registers. Matching on the
// class alone would also match other Flutter apps, so we additionally require
// the owning process to be running our exact executable.
constexpr wchar_t kFlutterWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

// Escape hatch for support/QA: deliberately start a second copy.
constexpr char kAllowMultipleInstancesFlag[] = "--allow-multiple-instances";

std::wstring GetImagePathForProcess(HANDLE process) {
  wchar_t buffer[MAX_PATH * 4];
  DWORD size = ARRAYSIZE(buffer);
  if (!::QueryFullProcessImageNameW(process, 0, buffer, &size)) {
    return std::wstring();
  }
  return std::wstring(buffer, size);
}

struct ExistingWindowSearch {
  DWORD own_pid = 0;
  std::wstring own_image;
  HWND found = nullptr;
};

BOOL CALLBACK FindExistingInstanceWindow(HWND hwnd, LPARAM lparam) {
  auto* search = reinterpret_cast<ExistingWindowSearch*>(lparam);

  wchar_t class_name[256];
  if (::GetClassNameW(hwnd, class_name, ARRAYSIZE(class_name)) == 0) {
    return TRUE;
  }
  if (::wcscmp(class_name, kFlutterWindowClassName) != 0) {
    return TRUE;
  }

  DWORD pid = 0;
  ::GetWindowThreadProcessId(hwnd, &pid);
  if (pid == 0 || pid == search->own_pid) {
    return TRUE;
  }

  HANDLE process = ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process == nullptr) {
    return TRUE;
  }
  std::wstring image = GetImagePathForProcess(process);
  ::CloseHandle(process);

  if (!image.empty() && !search->own_image.empty() &&
      ::_wcsicmp(image.c_str(), search->own_image.c_str()) == 0) {
    search->found = hwnd;
    return FALSE;  // Stop enumerating.
  }
  return TRUE;
}

// Brings the already-running copy to the front, so the double-click the user
// just made still feels like it did something.
void FocusRunningInstance() {
  ExistingWindowSearch search;
  search.own_pid = ::GetCurrentProcessId();
  search.own_image = GetImagePathForProcess(::GetCurrentProcess());

  ::EnumWindows(FindExistingInstanceWindow, reinterpret_cast<LPARAM>(&search));
  if (search.found == nullptr) {
    return;
  }

  if (::IsIconic(search.found)) {
    ::ShowWindow(search.found, SW_RESTORE);
  } else {
    ::ShowWindow(search.found, SW_SHOW);
  }
  ::SetForegroundWindow(search.found);
}

bool HasFlag(const std::vector<std::string>& arguments, const char* flag) {
  for (const std::string& argument : arguments) {
    if (argument == flag) {
      return true;
    }
  }
  return false;
}

}  // namespace

// Check if the Visual C++ 2015-2022 Redistributable runtime is available.
// Returns true if the required DLLs can be loaded, false otherwise.
bool IsVCRuntimeInstalled() {
  HMODULE hVcRuntime = LoadLibraryA("vcruntime140.dll");
  if (hVcRuntime) {
    FreeLibrary(hVcRuntime);
    return true;
  }
  return false;
}

// Show a dialog telling the user that VC++ runtime is required
// and offer to open the download page.
void PromptVCRuntimeInstall() {
  int result = MessageBoxW(
      nullptr,
      L"This application requires the Microsoft Visual C++ 2015-2022 "
      L"Redistributable to run.\n\n"
      L"Would you like to open the download page to install it?\n\n"
      L"After installing, please restart the application.",
      L"CLOUDPOS - Missing Dependency",
      MB_YESNO | MB_ICONWARNING);

  if (result == IDYES) {
    ShellExecuteW(nullptr, L"open",
        L"https://aka.ms/vs/17/release/vc_redist.x64.exe",
        nullptr, nullptr, SW_SHOWNORMAL);
  }
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Check for Visual C++ Redistributable before anything else
  if (!IsVCRuntimeInstalled()) {
    PromptVCRuntimeInstall();
    return EXIT_FAILURE;
  }

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();

  // Only one copy may run per Windows session. A second copy points at the
  // same Hive directory and fights the first one for its box locks, which
  // ends in a long stall on startup and can corrupt the boxes outright.
  // The handle is held for the lifetime of the process; Windows destroys the
  // mutex when we exit or crash, so a stale mutex can never lock a user out.
  HANDLE single_instance_mutex = nullptr;
  if (!HasFlag(command_line_arguments, kAllowMultipleInstancesFlag)) {
    single_instance_mutex =
        ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutexName);
    if (single_instance_mutex != nullptr &&
        ::GetLastError() == ERROR_ALREADY_EXISTS) {
      FocusRunningInstance();
      ::CloseHandle(single_instance_mutex);
      return EXIT_SUCCESS;
    }
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"CLOUDPOS", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (single_instance_mutex != nullptr) {
    ::CloseHandle(single_instance_mutex);
  }
  return EXIT_SUCCESS;
}
