#include "flutter_window.h"

#include <flutter/encodable_value.h>
#include <optional>
#include <shlobj.h>
#include <shobjidl.h>
#include <wrl/client.h>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {

constexpr UINT_PTR kOpenFilesCopyDataId = 0x4F494D47;

std::optional<std::string> FileSystemPathFromShellItem(IShellItem* item) {
  if (item == nullptr) {
    return std::nullopt;
  }

  PWSTR path = nullptr;
  if (FAILED(item->GetDisplayName(SIGDN_FILESYSPATH, &path)) || path == nullptr) {
    return std::nullopt;
  }

  std::string utf8_path = Utf8FromUtf16(path);
  CoTaskMemFree(path);
  if (utf8_path.empty()) {
    return std::nullopt;
  }
  return utf8_path;
}

std::vector<std::string> ShowFilePicker(HWND owner, bool pick_folder) {
  Microsoft::WRL::ComPtr<IFileOpenDialog> dialog;
  HRESULT hr =
      CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
                       IID_PPV_ARGS(&dialog));
  if (FAILED(hr)) {
    return {};
  }

  DWORD options = 0;
  hr = dialog->GetOptions(&options);
  if (FAILED(hr)) {
    return {};
  }

  options |= FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST;
  if (pick_folder) {
    options |= FOS_PICKFOLDERS;
  } else {
    options |= FOS_ALLOWMULTISELECT | FOS_FILEMUSTEXIST;
  }
  dialog->SetOptions(options);
  dialog->SetTitle(pick_folder ? L"Open Folder" : L"Open Files");

  hr = dialog->Show(owner);
  if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    return {};
  }
  if (FAILED(hr)) {
    return {};
  }

  std::vector<std::string> paths;
  if (pick_folder) {
    Microsoft::WRL::ComPtr<IShellItem> item;
    if (SUCCEEDED(dialog->GetResult(&item))) {
      if (auto path = FileSystemPathFromShellItem(item.Get())) {
        paths.push_back(*path);
      }
    }
    return paths;
  }

  Microsoft::WRL::ComPtr<IShellItemArray> items;
  if (FAILED(dialog->GetResults(&items)) || !items) {
    return {};
  }

  DWORD count = 0;
  if (FAILED(items->GetCount(&count))) {
    return {};
  }

  paths.reserve(count);
  for (DWORD index = 0; index < count; ++index) {
    Microsoft::WRL::ComPtr<IShellItem> item;
    if (FAILED(items->GetItemAt(index, &item))) {
      continue;
    }
    if (auto path = FileSystemPathFromShellItem(item.Get())) {
      paths.push_back(*path);
    }
  }

  return paths;
}

flutter::EncodableValue EncodableListFromPaths(
    const std::vector<std::string>& paths) {
  flutter::EncodableList values;
  values.reserve(paths.size());
  for (const auto& path : paths) {
    values.emplace_back(path);
  }
  return flutter::EncodableValue(std::move(values));
}

std::vector<std::string> DecodeOpenFilesCopyData(const COPYDATASTRUCT* copy_data) {
  if (copy_data == nullptr || copy_data->dwData != kOpenFilesCopyDataId ||
      copy_data->cbData == 0 || copy_data->lpData == nullptr) {
    return {};
  }

  const auto* payload = static_cast<const wchar_t*>(copy_data->lpData);
  size_t character_count = copy_data->cbData / sizeof(wchar_t);

  std::vector<std::string> paths;
  size_t index = 0;
  while (index < character_count) {
    const wchar_t* current = payload + index;
    size_t length = wcsnlen(current, character_count - index);
    if (length == 0) {
      break;
    }

    paths.push_back(Utf8FromUtf16(current));
    index += length + 1;
  }

  return paths;
}

void ShowInFileManager(const std::string& path) {
  if (path.empty()) {
    return;
  }

  std::wstring wide_path = Utf16FromUtf8(path);
  if (wide_path.empty()) {
    return;
  }

  PIDLIST_ABSOLUTE item_id = nullptr;
  if (FAILED(SHParseDisplayName(wide_path.c_str(), nullptr, &item_id, 0, nullptr)) ||
      item_id == nullptr) {
    return;
  }

  SHOpenFolderAndSelectItems(item_id, 0, nullptr, 0);
  CoTaskMemFree(item_id);
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

  file_open_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "oimg/file_open",
          &flutter::StandardMethodCodec::GetInstance());
  file_open_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "ready") {
          file_open_channel_ready_ = true;
          FlushPendingOpenFiles();
          result->Success();
          return;
        }
        if (call.method_name() == "pickFiles") {
          result->Success(EncodableListFromPaths(ShowFilePicker(GetHandle(), false)));
          return;
        }
        if (call.method_name() == "pickFolder") {
          result->Success(EncodableListFromPaths(ShowFilePicker(GetHandle(), true)));
          return;
        }
        if (call.method_name() == "showInFileManager") {
          const auto* path = std::get_if<std::string>(call.arguments());
          if (path != nullptr) {
            ShowInFileManager(*path);
          }
          result->Success();
          return;
        }

        result->NotImplemented();
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::QueueOpenFiles(const std::vector<std::string>& paths) {
  if (paths.empty()) {
    return;
  }

  pending_open_files_.push_back(paths);
  FlushPendingOpenFiles();
}

void FlutterWindow::OnDestroy() {
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
    case WM_COPYDATA: {
      auto* copy_data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
      QueueOpenFiles(DecodeOpenFilesCopyData(copy_data));
      ShowAndFocus();
      return TRUE;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::FlushPendingOpenFiles() {
  if (!file_open_channel_ready_ || !file_open_channel_) {
    return;
  }

  for (const auto& batch : pending_open_files_) {
    flutter::EncodableList values;
    values.reserve(batch.size());
    for (const auto& path : batch) {
      values.emplace_back(path);
    }
    file_open_channel_->InvokeMethod(
        "openFiles",
        std::make_unique<flutter::EncodableValue>(std::move(values)));
  }

  pending_open_files_.clear();
}

void FlutterWindow::ShowAndFocus() {
  ShowWindow(GetHandle(), SW_RESTORE);
  SetForegroundWindow(GetHandle());
}
