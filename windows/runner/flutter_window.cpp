#include "flutter_window.h"

#include <flutter/encodable_value.h>
#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {

constexpr UINT_PTR kOpenFilesCopyDataId = 0x4F494D47;

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
