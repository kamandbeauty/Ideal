#Requires -Version 5.1
<#
    پارسی‌گو — نصب‌کنندهٔ نسخهٔ ویندوز (بدون نیاز به دسترسی مدیر)

    اجرا: روی windows\install.bat دوبار کلیک کنید (یا همین فایل را با
    راست‌کلیک → Run with PowerShell).

    چه کار می‌کند:
      ۱) پایتون ۶۴بیتی را پیدا و بررسی می‌کند (۳٫۱۰ یا تازه‌تر)
      ۲) یک محیط مجازی در .venv می‌سازد و وابستگی‌های سبک (~۲۰۰ مگابایت) را
         نصب می‌کند — بدون torch، بدون GPU
      ۳) اگر بخواهید، مدل صوتی (~۴۷۰ مگابایت) را یک‌بار دانلود می‌کند
      ۴) میانبر «پارسی‌گو» را در دسکتاپ و منوی استارت می‌سازد

    هیچ چیزی در رجیستری ویندوز یا Program Files نوشته نمی‌شود؛ برای حذف،
    پوشهٔ پروژه (و در صورت تمایل %LOCALAPPDATA%\Parsigo) را پاک کنید.
#>

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$ProgressPreference = "SilentlyContinue"

$Root = Split-Path -Parent $PSScriptRoot
$Venv = Join-Path $Root ".venv"
$Py = Join-Path $Venv "Scripts\python.exe"
$PyW = Join-Path $Venv "Scripts\pythonw.exe"
$Req = Join-Path $PSScriptRoot "requirements-win.txt"
$Icon = Join-Path $Root "desktop\assets\parsigo.ico"

function Say($text, $color = "Gray") { Write-Host $text -ForegroundColor $color }
function Ok($text) { Say "  ✓ $text" "Green" }
function Warn($text) { Say "  ! $text" "Yellow" }
function Die($text, $hint = "") {
    Say ""
    Say "  ✗ $text" "Red"
    if ($hint) { Say "    $hint" "DarkGray" }
    Say ""
    Read-Host "برای بستن Enter بزنید"
    exit 1
}

Say ""
Say "  ╔══════════════════════════════════════════════════════════╗" "Cyan"
Say "  ║   پارسی‌گو — نصب نسخهٔ ویندوز (تبدیل متن فارسی به گفتار)  ║" "Cyan"
Say "  ╚══════════════════════════════════════════════════════════╝" "Cyan"
Say ""

# ---------------------------------------------------------------- 0) checks --
if (-not [Environment]::Is64BitOperatingSystem) {
    Die "این برنامه فقط روی ویندوز ۶۴بیتی اجرا می‌شود."
}

$webview = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}",
    "HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
) | Where-Object { Test-Path $_ }

if ($webview) {
    Ok "WebView2 Runtime نصب است (پنجرهٔ برنامه از آن استفاده می‌کند)"
} else {
    Warn "WebView2 Runtime پیدا نشد. اگر پنجرهٔ برنامه باز نشد، «Microsoft Edge WebView2 Runtime»"
    Warn "را از سایت مایکروسافت نصب کنید (رایگان، حدود ۲ مگابایت)."
}

# --------------------------------------------------------------- 1) Python --
Say ""
Say "  ۱/۴ — پیدا کردن پایتون ۶۴بیتی…" "White"

$candidates = @()
foreach ($c in @("py -3.12", "py -3.11", "py -3", "python")) { $candidates += $c }

$basePython = $null
$baseArgs = @()
foreach ($cand in $candidates) {
    $parts = $cand.Split(" ")
    $exe = $parts[0]
    $pre = @()
    if ($parts.Length -gt 1) { $pre = $parts[1..($parts.Length - 1)] }
    $cmd = Get-Command $exe -ErrorAction SilentlyContinue
    if (-not $cmd) { continue }
    try {
        $verOut = & $exe @pre "-c" "import sys;print('%d.%d'%sys.version_info[:2]);print(1 if sys.maxsize>2**32 else 0)" 2>$null
        if ($LASTEXITCODE -ne 0) { continue }
        $lines = @($verOut)
        $ver = [version]$lines[0]
        $is64 = $lines[1] -eq "1"
        if ($ver -ge [version]"3.10" -and $is64) {
            $basePython = $exe
            $baseArgs = $pre
            Ok "پایتون $ver پیدا شد ($exe)"
            break
        }
        if (-not $is64) { Warn "پایتون $ver سی‌ودو بیتی است — رد شد" }
        else { Warn "پایتون $ver قدیمی است — رد شد" }
    } catch { continue }
}

if (-not $basePython) {
    Die "پایتون ۳٫۱۰ یا تازه‌تر (۶۴بیتی) پیدا نشد." `
        "از python.org نسخهٔ ویندوز ۶۴بیتی را نصب کنید و گزینهٔ «Add python.exe to PATH» را تیک بزنید."
}

# ----------------------------------------------------------------- 2) venv --
Say ""
Say "  ۲/۴ — ساخت محیط مجازی و نصب وابستگی‌ها (~۲۰۰ مگابایت)…" "White"

if (-not (Test-Path $Py)) {
    & $basePython @baseArgs "-m" "venv" $Venv
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Py)) { Die "ساخت محیط مجازی ناموفق بود." }
    Ok "محیط مجازی ساخته شد: .venv"
} else {
    Ok "محیط مجازی از قبل وجود دارد"
}

& $Py "-m" "pip" "install" "--quiet" "--upgrade" "pip" "wheel" "setuptools"
if ($LASTEXITCODE -ne 0) { Warn "به‌روزرسانی pip ناموفق بود — ادامه می‌دهیم" }

Say "  نصب بسته‌ها… (چند دقیقه؛ اگر قطع شد همین فایل را دوباره اجرا کنید)"
& $Py "-m" "pip" "install" "--disable-pip-version-check" "-r" $Req
if ($LASTEXITCODE -ne 0) {
    Die "نصب وابستگی‌ها ناموفق بود." `
        "اینترنت را بررسی کنید. در شبکه‌های محدود: pip install -r windows\requirements-win.txt --proxy http://user:pass@host:port"
}
Ok "وابستگی‌ها نصب شدند"

# ------------------------------------------------------------------ 3) model --
Say ""
Say "  ۳/۴ — مدل صوتی (اختیاری، ~۴۷۰ مگابایت)" "White"
Say "  این دانلود فقط یک‌بار لازم است؛ بعد از آن برنامه کاملاً آفلاین کار می‌کند."
Say "  می‌توانید الان رد کنید و بار اولی که برنامه را باز می‌کنید انجام دهید."
$answer = Read-Host "  همین حالا دانلود شود؟ (y/n)"
if ($answer -match "^(y|Y|ب|بله|yes)") {
    & $Py "-m" "desktop.main" "--install-model"
    if ($LASTEXITCODE -ne 0) {
        Warn "دانلود کامل نشد. داخل برنامه دکمهٔ «نصب مدل» را دوباره امتحان کنید،"
        Warn "یا در همان صفحه آینهٔ https://hf-mirror.com را وارد کنید."
    } else { Ok "مدل نصب شد" }
} else {
    Warn "رد شد — بار اول باز شدن برنامه، صفحهٔ نصب مدل نمایش داده می‌شود."
}

# --------------------------------------------------------------- 4) shortcut --
Say ""
Say "  ۴/۴ — ساخت میانبر…" "White"

if (Test-Path $PyW) {
    & (Join-Path $PSScriptRoot "shortcut.ps1") `
        -Target $PyW `
        -Arguments ('"' + (Join-Path $Root "desktop\main.py") + '"') `
        -WorkDir $Root `
        -Icon $Icon
} else {
    Warn "pythonw.exe پیدا نشد؛ میانبر ساخته نشد."
}

Say ""
Say "  ✓ نصب کامل شد." "Green"
Say "    اجرا: میانبر «پارسی‌گو» در دسکتاپ، یا windows\run.bat" "Gray"
Say "    مستندات: docs\WINDOWS.md    |    گزارش خطا: %LOCALAPPDATA%\Parsigo\logs\app.log" "DarkGray"
Say ""

$run = Read-Host "  همین حالا برنامه باز شود؟ (y/n)"
if ($run -match "^(y|Y|ب|بله|yes)") {
    Start-Process -FilePath $PyW -ArgumentList ('"' + (Join-Path $Root "desktop\main.py") + '"') -WorkingDirectory $Root
}
