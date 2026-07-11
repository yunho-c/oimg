const isMacAppStoreBuild = bool.fromEnvironment('OIMG_MAS_BUILD');
const isWindowsStoreBuild = bool.fromEnvironment('OIMG_WINDOWS_STORE_BUILD');
const isStoreBuild = isMacAppStoreBuild || isWindowsStoreBuild;
