#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <string>
#include <vector>

#include "file_associations.h"
#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kAppMutexName[] = L"Local\\com.yunho-c.oimg.instance";
constexpr wchar_t kWindowTitle[] = L"OIMG";
constexpr UINT_PTR kOpenFilesCopyDataId = 0x4F494D47;

std::vector<wchar_t> EncodeOpenFilesCopyData(const std::vector<std::wstring>& paths) {
  size_t character_count = 1;
  for (const auto& path : paths) {
    character_count += path.size() + 1;
  }

  std::vector<wchar_t> payload(character_count, L'\0');
  size_t index = 0;
  for (const auto& path : paths) {
    std::copy(path.begin(), path.end(), payload.begin() + index);
    index += path.size() + 1;
  }
  return payload;
}

HWND WaitForExistingWindow() {
  for (int attempts = 0; attempts < 100; ++attempts) {
    HWND window = FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", kWindowTitle);
    if (window != nullptr) {
      return window;
    }
    Sleep(50);
  }

  return nullptr;
}

bool ForwardToExistingInstance(const std::vector<std::wstring>& paths) {
  HWND window = WaitForExistingWindow();
  if (window == nullptr) {
    return false;
  }

  std::vector<wchar_t> payload = EncodeOpenFilesCopyData(paths);
  COPYDATASTRUCT copy_data{};
  copy_data.dwData = kOpenFilesCopyDataId;
  copy_data.cbData = static_cast<DWORD>(payload.size() * sizeof(wchar_t));
  copy_data.lpData = payload.data();

  SendMessage(window, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&copy_data));
  ShowWindow(window, SW_RESTORE);
  SetForegroundWindow(window);
  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  HANDLE instance_mutex = CreateMutex(nullptr, TRUE, kAppMutexName);
  const bool already_running = GetLastError() == ERROR_ALREADY_EXISTS;
  if (already_running) {
    ForwardToExistingInstance(GetCommandLineArgumentsW());
    ::CoUninitialize();
    if (instance_mutex != nullptr) {
      CloseHandle(instance_mutex);
    }
    return EXIT_SUCCESS;
  }

  EnsureFileAssociations();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kWindowTitle, origin, size)) {
    if (instance_mutex != nullptr) {
      CloseHandle(instance_mutex);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (instance_mutex != nullptr) {
    CloseHandle(instance_mutex);
  }
  return EXIT_SUCCESS;
}
