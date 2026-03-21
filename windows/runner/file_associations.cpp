#include "file_associations.h"

#include <shlobj.h>
#include <windows.h>

#include <array>
#include <string>

namespace {

constexpr wchar_t kAppDisplayName[] = L"OIMG";
constexpr wchar_t kExecutableName[] = L"oimg.exe";
constexpr wchar_t kProgId[] = L"OIMG.AssocFile.Image";
constexpr std::array<const wchar_t*, 8> kSupportedExtensions = {
    L".png", L".jpg", L".jpeg", L".gif",
    L".bmp", L".webp", L".tif",  L".tiff",
};

bool SetStringValue(HKEY root,
                    const std::wstring& subkey,
                    const wchar_t* name,
                    const std::wstring& value) {
  HKEY key = nullptr;
  if (RegCreateKeyExW(root, subkey.c_str(), 0, nullptr, 0, KEY_SET_VALUE,
                      nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return false;
  }

  const auto* bytes = reinterpret_cast<const BYTE*>(value.c_str());
  DWORD size = static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t));
  LSTATUS status = RegSetValueExW(key, name, 0, REG_SZ, bytes, size);
  RegCloseKey(key);
  return status == ERROR_SUCCESS;
}

bool SetEmptyValue(HKEY root, const std::wstring& subkey, const wchar_t* name) {
  HKEY key = nullptr;
  if (RegCreateKeyExW(root, subkey.c_str(), 0, nullptr, 0, KEY_SET_VALUE,
                      nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return false;
  }

  LSTATUS status = RegSetValueExW(key, name, 0, REG_NONE, nullptr, 0);
  RegCloseKey(key);
  return status == ERROR_SUCCESS;
}

std::wstring CurrentExecutablePath() {
  std::wstring path;
  path.resize(MAX_PATH);
  DWORD length = GetModuleFileNameW(nullptr, path.data(),
                                    static_cast<DWORD>(path.size()));
  while (length == path.size()) {
    path.resize(path.size() * 2);
    length = GetModuleFileNameW(nullptr, path.data(),
                                static_cast<DWORD>(path.size()));
  }
  path.resize(length);
  return path;
}

}  // namespace

bool EnsureFileAssociations() {
  const std::wstring executable_path = CurrentExecutablePath();
  if (executable_path.empty()) {
    return false;
  }

  const std::wstring open_command =
      L"\"" + executable_path + L"\" \"%*\"";
  const std::wstring default_icon = executable_path + L",0";
  const std::wstring applications_key =
      L"Software\\Classes\\Applications\\" + std::wstring(kExecutableName);
  const std::wstring prog_id_key =
      L"Software\\Classes\\" + std::wstring(kProgId);

  bool success = true;
  success &= SetStringValue(HKEY_CURRENT_USER, applications_key, L"FriendlyAppName",
                            kAppDisplayName);
  success &= SetStringValue(HKEY_CURRENT_USER, applications_key + L"\\shell\\open\\command",
                            nullptr, open_command);
  success &= SetStringValue(HKEY_CURRENT_USER, applications_key + L"\\DefaultIcon",
                            nullptr, default_icon);

  success &= SetStringValue(HKEY_CURRENT_USER, prog_id_key, nullptr,
                            L"OIMG Image");
  success &= SetStringValue(HKEY_CURRENT_USER, prog_id_key + L"\\shell\\open\\command",
                            nullptr, open_command);
  success &= SetStringValue(HKEY_CURRENT_USER, prog_id_key + L"\\DefaultIcon",
                            nullptr, default_icon);

  for (const auto* extension : kSupportedExtensions) {
    success &= SetEmptyValue(HKEY_CURRENT_USER,
                             applications_key + L"\\SupportedTypes", extension);
    success &= SetEmptyValue(HKEY_CURRENT_USER,
                             L"Software\\Classes\\" + std::wstring(extension) +
                                 L"\\OpenWithProgids",
                             kProgId);
  }

  if (success) {
    SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
  }

  return success;
}
