#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shellapi.h>

#include "flutter_window.h"
#include "utils.h"

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

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

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
  return EXIT_SUCCESS;
}
