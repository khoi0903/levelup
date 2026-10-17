# Build AAB release và đẩy lên Google Play qua Play Developer API (Gradle Play Publisher).
# Hướng dẫn chuẩn bị khoá: docs/play-publish.md
#
# Ví dụ (chạy trong thư mục app):
#   .\publish-play.ps1                     # build + đẩy lên track alpha (test kín)
#   .\publish-play.ps1 -Track internal     # thử nội bộ
#   .\publish-play.ps1 -BumpBuild          # tăng số build trong pubspec (1.0.8+9 -> 1.0.8+10) rồi build
#   .\publish-play.ps1 -SkipBuild          # chỉ đẩy AAB đã build sẵn
param(
    [ValidateSet('internal', 'alpha', 'beta', 'production')]
    [string]$Track = 'alpha',
    [ValidateSet('completed', 'draft', 'inProgress', 'halted')]
    [string]$ReleaseStatus = 'completed',
    [string]$ApiBaseUrl = 'https://levelup-backend-kjqn.onrender.com',
    [switch]$BumpBuild,
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$appDir = $PSScriptRoot
$androidDir = Join-Path $appDir 'android'

foreach ($f in 'play-service-account.json', 'key.properties') {
    if (-not (Test-Path (Join-Path $androidDir $f))) {
        throw "Thiếu app/android/$f (xem docs/play-publish.md). Không đẩy bản ký khoá debug lên Play."
    }
}

$pubspec = Join-Path $appDir 'pubspec.yaml'
$text = [IO.File]::ReadAllText($pubspec)
$m = [regex]::Match($text, '(?m)^version:\s*(\S+)\+(\d+)\s*$')
if (-not $m.Success) { throw 'Không đọc được dòng version: x.y.z+N trong pubspec.yaml' }
$name = $m.Groups[1].Value
$code = [int]$m.Groups[2].Value
if ($BumpBuild) {
    $code++
    $text = $text.Remove($m.Index, $m.Length).Insert($m.Index, "version: $name+$code")
    [IO.File]::WriteAllText($pubspec, $text, (New-Object Text.UTF8Encoding $false))
    Write-Host "Đã tăng số build: $name+$code (nhớ commit pubspec.yaml)"
}
Write-Host "Phiên bản $name ($code) -> track '$Track', trạng thái '$ReleaseStatus'"

Push-Location $appDir
try {
    if (-not $SkipBuild) {
        flutter build appbundle --release "--dart-define=API_BASE_URL=$ApiBaseUrl"
        if ($LASTEXITCODE -ne 0) { throw 'flutter build appbundle lỗi' }
    }
    $bundleDir = Join-Path $appDir 'build\app\outputs\bundle\release'
    if (-not (Test-Path (Join-Path $bundleDir 'app-release.aab'))) { throw "Không thấy $bundleDir\app-release.aab" }

    Set-Location $androidDir
    # --rerun: Gradle không được coi bước tải lên là "up-to-date" và bỏ qua khi chạy lại cùng AAB
    .\gradlew.bat publishReleaseBundle --rerun "--artifact-dir=$bundleDir" "--track=$Track" "--release-status=$ReleaseStatus"
    if ($LASTEXITCODE -ne 0) { throw 'Đẩy lên Google Play lỗi (xem log Gradle ở trên)' }
    Write-Host "Xong: $name ($code) đã lên track '$Track'."
}
finally {
    Pop-Location
}
