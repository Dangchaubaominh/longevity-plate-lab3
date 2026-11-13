param(
    [ValidateSet('doctor', 'init', 'ui', 'status')]
    [string]$Mode = 'doctor'
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artemisRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '../tools/artemis'))
$artemisExe = Join-Path $artemisRoot '.venv/Scripts/artemis.exe'
if (-not (Test-Path -LiteralPath $artemisExe)) {
    throw "Chua cai xong ARTEMIS tai $artemisRoot. Xem docs/ASSIGNMENT3_FINISH_CHECKLIST_VI.md."
}

$names = @('PATH', 'ARTEMIS_APP_DIR', 'ARTEMIS_HELPER_AUTO_INSTALL', 'PYTHONUTF8')
$previous = @{}
foreach ($name in $names) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$exitCode = 1
Push-Location -LiteralPath $artemisRoot
try {
    # Keep API keys and traces inside the Flutter repo's ignored artifacts folder.
    $env:ARTEMIS_APP_DIR = Join-Path $projectRoot 'artifacts/artemis-runtime'
    New-Item -ItemType Directory -Force -Path $env:ARTEMIS_APP_DIR | Out-Null
    $env:ARTEMIS_HELPER_AUTO_INSTALL = 'false'
    $env:PYTHONUTF8 = '1'
    $adbDirectory = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools'
    $scrcpyDirectory = [IO.Path]::GetFullPath((Join-Path $projectRoot '../tools/scrcpy/scrcpy-win64-v5.0.1'))
    if (Test-Path -LiteralPath (Join-Path $scrcpyDirectory 'scrcpy.exe')) {
        $env:PATH = "$scrcpyDirectory;$env:PATH"
    }
    if (Test-Path -LiteralPath (Join-Path $adbDirectory 'adb.exe')) {
        $env:PATH = "$adbDirectory;$env:PATH"
    }
    & $artemisExe $Mode
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
    foreach ($name in $names) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
}
exit $exitCode
