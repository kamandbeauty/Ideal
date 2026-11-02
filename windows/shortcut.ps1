# پارسی‌گو — ساخت/حذف میانبر در دسکتاپ و منوی استارت
#
#   powershell -ExecutionPolicy Bypass -File shortcut.ps1 -Target "C:\...\pythonw.exe" `
#       -Arguments '"C:\...\desktop\main.py"' -WorkDir "C:\...\Parsigo" -Icon "C:\...\parsigo.ico"
#
#   ... -Remove        # همهٔ میانبرهای پارسی‌گو را پاک می‌کند
#
# توسط install.ps1 صدا زده می‌شود؛ برای نسخهٔ قابل حمل هم make-shortcut.ps1
# همین کار را داخل خودِ پوشه انجام می‌دهد.

param(
    [string]$Target = "",
    [string]$Arguments = "",
    [string]$WorkDir = "",
    [string]$Icon = "",
    [string]$Name = "پارسی‌گو",
    [switch]$Remove
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$places = @(
    [Environment]::GetFolderPath("Desktop"),
    (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs")
) | Where-Object { $_ -and (Test-Path $_) }

$shell = New-Object -ComObject WScript.Shell

if ($Remove) {
    $n = 0
    foreach ($dir in $places) {
        $lnk = Join-Path $dir "$Name.lnk"
        if (Test-Path $lnk) { Remove-Item $lnk -Force; $n++; Write-Host "  حذف شد: $lnk" }
    }
    Write-Host "  $n میانبر پاک شد."
    exit 0
}

if (-not $Target -or -not (Test-Path $Target)) {
    Write-Host "  خطا: فایل اجرایی پیدا نشد: $Target" -ForegroundColor Red
    exit 1
}

foreach ($dir in $places) {
    $lnkPath = Join-Path $dir "$Name.lnk"
    $lnk = $shell.CreateShortcut($lnkPath)
    $lnk.TargetPath = $Target
    if ($Arguments) { $lnk.Arguments = $Arguments }
    if ($WorkDir) { $lnk.WorkingDirectory = $WorkDir }
    if ($Icon -and (Test-Path $Icon)) { $lnk.IconLocation = $Icon }
    $lnk.Description = "پارسی‌گو — تبدیل متن فارسی به گفتار (کاملاً آفلاین)"
    $lnk.WindowStyle = 1
    $lnk.Save()
    Write-Host "  میانبر ساخته شد: $lnkPath"
}
exit 0
