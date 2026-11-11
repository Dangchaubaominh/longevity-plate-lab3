param([switch]$Firebase, [switch]$SkipChecks, [string]$ReportApiUrl = $env:REPORT_API_URL)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
# Keep build caches on the project drive; C: may not have room for R8.
# Dependency caches must be real directories, not junctions across drives.
$previousGradleHome = $env:GRADLE_USER_HOME
$env:GRADLE_USER_HOME = Join-Path $projectRoot '.gradle-local'
$kotlinStrategyEnv = 'Env:ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy'
$previousKotlinStrategy = [Environment]::GetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy')
Set-Item -LiteralPath $kotlinStrategyEnv -Value 'in-process'
Push-Location -LiteralPath $projectRoot
try {
    $artifactDir = Join-Path $projectRoot 'artifacts/android'
    New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
    New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null
    $modulesDir = Join-Path $env:GRADLE_USER_HOME 'caches/modules-2'
    if ((Test-Path -LiteralPath $modulesDir) -and
        (Get-Item -LiteralPath $modulesDir).LinkType) {
        throw 'Cache modules-2 đang là junction/symlink. Dùng thư mục cache đầy đủ trên ổ dự án theo docs/ANDROID-APK.md.'
    }
    if ($Firebase -and (Get-Content lib/firebase_options.dart -Raw).Contains('File giữ chỗ')) {
        throw 'Chưa cấu hình Firebase. Chạy flutterfire configure trước khi build bản Firebase.'
    }
    if (-not $SkipChecks) {
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Không lấy được dependencies.' }
        & flutter analyze
        if ($LASTEXITCODE -ne 0) { throw 'flutter analyze chưa đạt.' }
        & flutter test
        if ($LASTEXITCODE -ne 0) { throw 'flutter test chưa đạt.' }
    }
    $buildArgs = @('build', 'apk', '--release')
    if (-not $Firebase) { $buildArgs += '--dart-define=USE_LOCAL_SERVICES=true' }
    if ($Firebase -and -not [string]::IsNullOrWhiteSpace($ReportApiUrl)) {
        $buildArgs += "--dart-define=REPORT_API_URL=$ReportApiUrl"
    }
    & flutter @buildArgs
    if ($LASTEXITCODE -ne 0) { throw 'Build Android thất bại.' }
    $fileName = if ($Firebase) { 'longevity-plate-firebase.apk' } else { 'longevity-plate-offline.apk' }
    $target = Join-Path $artifactDir $fileName
    Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' -Destination $target -Force
    $hash = Get-FileHash -LiteralPath $target -Algorithm SHA256
    "$($hash.Hash)  $fileName" | Set-Content -LiteralPath "$target.sha256" -Encoding ascii
    Write-Output "APK: $target"
} finally {
    $env:GRADLE_USER_HOME = $previousGradleHome
    if ($null -eq $previousKotlinStrategy) {
        Remove-Item -LiteralPath $kotlinStrategyEnv -ErrorAction SilentlyContinue
    } else {
        Set-Item -LiteralPath $kotlinStrategyEnv -Value $previousKotlinStrategy
    }
    Pop-Location
}
