param(
  [string] $Version,
  [string] $ReleaseDir = "build\windows\x64\runner\Release",
  [string] $OutputDir = "dist\windows",
  [string] $OutputBaseFilename
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Get-RepoPath([string] $Path) {
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }

  return [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
}

if ([string]::IsNullOrWhiteSpace($Version)) {
  $versionLine = Get-Content (Join-Path $repoRoot "pubspec.yaml") |
    Where-Object { $_ -match '^version:\s*([^+]+)' } |
    Select-Object -First 1

  if ($null -eq $versionLine -or $versionLine -notmatch '^version:\s*([^+]+)') {
    throw "Could not read version from pubspec.yaml"
  }

  $Version = $Matches[1]
}

if ([string]::IsNullOrWhiteSpace($OutputBaseFilename)) {
  $OutputBaseFilename = "OIMG-$Version-windows-x64-setup"
}

$iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if ($null -eq $iscc) {
  $fallback = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
  if (-not (Test-Path $fallback)) {
    throw "ISCC.exe was not found. Install Inno Setup 6.3 or newer."
  }

  $isccPath = $fallback
} else {
  $isccPath = $iscc.Source
}

$releaseDirPath = Get-RepoPath $ReleaseDir
$outputDirPath = Get-RepoPath $OutputDir
$iconPath = Get-RepoPath "windows\runner\resources\app_icon.ico"
$issPath = Get-RepoPath "scripts\windows\installer\oimg.iss"

$exePath = Join-Path $releaseDirPath "oimg.exe"
if (-not (Test-Path $exePath)) {
  throw "Expected Windows executable not found: $exePath"
}

if (-not (Test-Path $iconPath)) {
  throw "Expected installer icon not found: $iconPath"
}

New-Item -ItemType Directory -Force -Path $outputDirPath | Out-Null

$setupPath = Join-Path $outputDirPath "$OutputBaseFilename.exe"
if (Test-Path $setupPath) {
  Remove-Item $setupPath
}

& $isccPath `
  "/DAppVersion=$Version" `
  "/DSourceDir=$releaseDirPath" `
  "/DOutputDir=$outputDirPath" `
  "/DOutputBaseFilename=$OutputBaseFilename" `
  "/DIconPath=$iconPath" `
  $issPath

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

if (-not (Test-Path $setupPath)) {
  throw "Expected Windows installer not found: $setupPath"
}

$hash = (Get-FileHash -Algorithm SHA256 $setupPath).Hash.ToLowerInvariant()
Set-Content -Path "$setupPath.sha256" -Value "$hash  $(Split-Path -Leaf $setupPath)"

Write-Host "Created $setupPath"
