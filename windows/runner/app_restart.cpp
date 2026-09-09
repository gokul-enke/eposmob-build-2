#include "app_restart.h"

#include <windows.h>
#include <tlhelp32.h>
#include <cerrno>
#include <cstdlib>
#include <memory>

namespace {
constexpr char kHelperFlag[] = "--cloudpos-restart-helper";
constexpr DWORD kGraceMs = 4000;
constexpr DWORD kExitMs = 10000;

struct CloseHandleDeleter {
  void operator()(void* handle) const {
    if (handle && handle != INVALID_HANDLE_VALUE) CloseHandle(handle);
  }
};
using OwnedHandle = std::unique_ptr<void, CloseHandleDeleter>;

std::wstring ImagePath(HANDLE process) {
  std::wstring path(32768, L'\0');
  DWORD length = static_cast<DWORD>(path.size());
  if (!QueryFullProcessImageNameW(process, 0, path.data(), &length)) return {};
  path.resize(length);
  return path;
}

ULONGLONG CreatedAt(HANDLE process) {
  FILETIME created{}, exited{}, kernel{}, user{};
  if (!GetProcessTimes(process, &created, &exited, &kernel, &user)) return 0;
  return (static_cast<ULONGLONG>(created.dwHighDateTime) << 32) |
      created.dwLowDateTime;
}

bool Launch(const std::wstring& path, const std::wstring& arguments) {
  // Explicit application path and no shell: spaces and punctuation are literal.
  std::wstring command = L"\"" + path + L"\"" + arguments;
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESHOWWINDOW;
  startup.wShowWindow = SW_SHOWNORMAL;
  PROCESS_INFORMATION process{};
  if (!CreateProcessW(path.c_str(), command.data(), nullptr, nullptr, FALSE,
                      0, nullptr, nullptr, &startup, &process)) {
    return false;
  }
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  return true;
}

struct Target {
  DWORD pid;
  OwnedHandle process;
};

BOOL CALLBACK RequestClose(HWND window, LPARAM parameter) {
  const auto* targets = reinterpret_cast<const std::vector<Target>*>(parameter);
  DWORD pid = 0;
  GetWindowThreadProcessId(window, &pid);
  for (const auto& target : *targets) {
    if (target.pid == pid &&
        WaitForSingleObject(target.process.get(), 0) == WAIT_TIMEOUT) {
      PostMessageW(window, WM_CLOSE, 0, 0);
      break;
    }
  }
  return TRUE;
}

int Fail(const wchar_t* message) {
  MessageBoxW(nullptr, message, L"CloudPOS restart", MB_OK | MB_ICONERROR);
  return EXIT_FAILURE;
}

int Restart(DWORD parent_pid, ULONGLONG parent_created) {
  OwnedHandle restart_lock(CreateMutexW(nullptr, TRUE,
      L"Local\\CLOUDPOS.RestartInProgress"));
  if (!restart_lock) return Fail(L"Couldn't prepare a restart. Close CloudPOS and open it again.");
  if (GetLastError() == ERROR_ALREADY_EXISTS) return EXIT_SUCCESS;

  const auto path = ImagePath(GetCurrentProcess());
  DWORD session = 0;
  if (path.empty() || !ProcessIdToSessionId(GetCurrentProcessId(), &session)) {
    return Fail(L"Couldn't identify this installation. Close CloudPOS and open it again.");
  }
  // Pin the requesting process by handle and creation time, not PID alone.
  OwnedHandle parent(OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION |
      SYNCHRONIZE | PROCESS_TERMINATE, FALSE, parent_pid));
  DWORD parent_session = 0;
  if (!parent || !ProcessIdToSessionId(parent_pid, &parent_session) ||
      parent_session != session || CreatedAt(parent.get()) != parent_created ||
      _wcsicmp(ImagePath(parent.get()).c_str(), path.c_str()) != 0) {
    return Fail(L"The original CloudPOS process could not be verified. No processes were stopped.");
  }

  std::vector<Target> targets;
  targets.push_back({parent_pid, std::move(parent)});
  OwnedHandle snapshot(CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0));
  if (snapshot.get() == INVALID_HANDLE_VALUE) {
    return Fail(L"Couldn't check running CloudPOS copies. No processes were stopped.");
  }
  PROCESSENTRY32W entry{};
  entry.dwSize = sizeof(entry);
  if (!Process32FirstW(snapshot.get(), &entry)) {
    return Fail(L"Couldn't check running CloudPOS copies. No processes were stopped.");
  }
  do {
    const DWORD pid = entry.th32ProcessID;
    DWORD candidate_session = 0;
    if (pid == parent_pid || pid == GetCurrentProcessId() ||
        !ProcessIdToSessionId(pid, &candidate_session) || candidate_session != session) continue;
    OwnedHandle query(OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid));
    if (!query || _wcsicmp(ImagePath(query.get()).c_str(), path.c_str()) != 0) continue;
    OwnedHandle process(OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION |
        SYNCHRONIZE | PROCESS_TERMINATE, FALSE, pid));
    if (!process) {
      return Fail(L"Windows wouldn't allow a CloudPOS copy to close. Close that copy manually and try again.");
    }
    const auto created = CreatedAt(query.get());
    if (created == 0 || CreatedAt(process.get()) != created) continue;
    targets.push_back({pid, std::move(process)});
  } while (Process32NextW(snapshot.get(), &entry));

  EnumWindows(RequestClose, reinterpret_cast<LPARAM>(&targets));
  const ULONGLONG deadline = GetTickCount64() + kGraceMs;
  for (const auto& target : targets) {
    const ULONGLONG now = GetTickCount64();
    const DWORD remaining = now < deadline ? static_cast<DWORD>(deadline - now) : 0;
    if (WaitForSingleObject(target.process.get(), remaining) == WAIT_OBJECT_0) continue;
    // Only a verified CloudPOS executable from this installation/session can
    // reach this fallback. Never kill by a generic process name or child tree.
    if (!TerminateProcess(target.process.get(), EXIT_FAILURE) &&
        WaitForSingleObject(target.process.get(), 0) != WAIT_OBJECT_0) {
      return Fail(L"A CloudPOS process could not be stopped. Close it manually, then open CloudPOS again.");
    }
    if (WaitForSingleObject(target.process.get(), kExitMs) != WAIT_OBJECT_0) {
      return Fail(L"CloudPOS is still closing. A new copy was not started. Wait a moment, then open CloudPOS again.");
    }
  }
  // The OS has now released each exited process's files and instance mutex.
  return Launch(path, L"") ? EXIT_SUCCESS : Fail(
      L"CloudPOS closed, but Windows couldn't reopen it. Please use your CloudPOS shortcut.");
}

bool ParseNumber(const std::string& text, unsigned long long* value) {
  if (text.empty() || text.find_first_not_of("0123456789") != std::string::npos) return false;
  errno = 0;
  char* end = nullptr;
  *value = std::strtoull(text.c_str(), &end, 10);
  return errno == 0 && end && *end == '\0' && *value != 0;
}
}  // namespace

bool BeginCloudPosRestart() {
  const auto path = ImagePath(GetCurrentProcess());
  const auto created = CreatedAt(GetCurrentProcess());
  if (path.empty() || created == 0) return false;
  return Launch(path, L" --cloudpos-restart-helper " +
      std::to_wstring(GetCurrentProcessId()) + L" " + std::to_wstring(created));
}

bool RunCloudPosRestartHelper(const std::vector<std::string>& arguments,
                             int* exit_code) {
  if (arguments.empty() || arguments[0] != kHelperFlag) return false;
  unsigned long long pid = 0, created = 0;
  if (arguments.size() != 3 || !ParseNumber(arguments[1], &pid) ||
      pid > MAXDWORD || !ParseNumber(arguments[2], &created)) {
    *exit_code = EXIT_FAILURE;
  } else {
    *exit_code = Restart(static_cast<DWORD>(pid), created);
  }
  return true;
}
