param(
    [ValidateSet("run", "build")]
    [string]$Command = "run",

    [ValidateSet("debug", "profile", "release")]
    [string]$Mode = "debug",

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs = @()
)

$ErrorActionPreference = "Stop"

function Get-RustupDefaultHost {
    $line = rustup show | Select-String -Pattern "^Default host:\s+(.+)$" | Select-Object -First 1
    if ($null -eq $line) {
        throw "Unable to determine rustup default host."
    }
    return $line.Matches[0].Groups[1].Value.Trim()
}

if (-not (($PSVersionTable.PSEdition -eq "Desktop") -or $IsWindows)) {
    throw "This script only supports Windows."
}

$targetHost = "x86_64-pc-windows-msvc"
$targetToolchain = "stable-$targetHost"
$originalHost = Get-RustupDefaultHost

Write-Host "Ensuring Rust toolchain $targetToolchain is installed..."
rustup toolchain install $targetToolchain --force-non-host

try {
    if ($originalHost -ne $targetHost) {
        Write-Host "Temporarily setting rustup default host to $targetHost..."
        rustup set default-host $targetHost
    }

    if ($Command -eq "run") {
        & flutter run -d windows "--$Mode" @FlutterArgs
    } else {
        & flutter build windows "--$Mode" @FlutterArgs
    }

    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
} finally {
    if ($originalHost -ne $targetHost) {
        Write-Host "Restoring rustup default host to $originalHost..."
        rustup set default-host $originalHost
    }
}
