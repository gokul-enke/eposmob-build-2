#ifndef RUNNER_APP_RESTART_H_
#define RUNNER_APP_RESTART_H_

#include <string>
#include <vector>
#include <windows.h>

// Launches a short-lived helper from this executable. The helper owns shutdown
// and waits for the old processes to exit before starting the replacement.
bool BeginCloudPosRestart(HANDLE* helper_process);
inline UINT CloudPosPrepareRestartMessage() {
  return RegisterWindowMessageW(L"CLOUDPOS.PrepareRestart.v1");
}
bool RunCloudPosRestartHelper(const std::vector<std::string>& arguments,
                             int* exit_code);

#endif
