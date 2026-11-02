#!/usr/bin/env python3
"""Build a self-contained Windows copy of Parsigo — no Python required.

    python windows/build_portable.py                 # -> dist/Parsigo-1.1.0-windows-x64.zip
    python windows/build_portable.py --with-model     # also bundle the 470MB model
    python windows/build_portable.py --python-version 3.12

The script runs on Windows, Linux or macOS: it never executes the Windows
binaries it collects, it only unpacks them. That means the same command works
on a build server (see .github/workflows/windows.yml) as on your laptop.

What goes in:

    Parsigo-<ver>-windows-x64/
      Parsigo.exe            launcher (zig cc cross-compiled, GUI subsystem)
      python/                standalone CPython + every runtime wheel
      desktop/ scripts/ web/ voices/ docs/
      portable.txt           keeps data + model inside this folder
      README-FIRST.txt       what to do next (Persian)
      Make-Shortcut.cmd      desktop/Start-Menu shortcut with the app icon

Two downloads are involved:
  * CPython for Windows, from astral-sh/python-build-standalone (GitHub)
  * the wheels, from PyPI, for cp<ver>-win_amd64

Both are cached in ``.build-cache/`` so a rebuild is offline and quick.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WINDOWS = ROOT / "windows"
CACHE = ROOT / ".build-cache"
REQS = WINDOWS / "requirements-win.txt"

# packages on PyPI that only publish an sdist (no wheel) — they are pure
# Python, so a universal wheel built here is exactly what the bundle needs
SDIST_ONLY = ("proxy_tools",)

PBS_REPO = "astral-sh/python-build-standalone"
PBS_ASSET = "cpython-{ver}.*-x86_64-pc-windows-msvc-install_only_stripped.tar.gz"

# Known-good 3.11 build, used when the GitHub API is rate-limited or offline
# (shared CI runner IPs hit the 60-requests/hour anonymous limit routinely).
PBS_FALLBACK = {
    "3.11": "https://github.com/astral-sh/python-build-standalone/releases/download/"
            "20261026/cpython-3.11.18+20261026-x86_64-pc-windows-msvc-install_only_stripped.tar.gz",
}


def _read_version() -> str:
    try:
        text = (ROOT / "desktop" / "__init__.py").read_text(encoding="utf-8")
        return re.search(r'__version__\s*=\s*"([^"]+)"', text).group(1)
    except Exception:  # noqa: BLE001
        return "0.0.0"


APP_VERSION = _read_version()


def log(msg: str) -> None:
    print(msg, flush=True)


def warn(msg: str) -> None:
    print(f"  ! {msg}", flush=True)


# --------------------------------------------------------------------------- #
# toolchain: an isolated venv for pip/zig, so the host env is never touched
# --------------------------------------------------------------------------- #
def tool_python() -> Path:
    venv = CACHE / "toolvenv"
    py = venv / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    if not py.exists():
        log("• creating build toolchain venv (pip, wheel, setuptools)")
        venv.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([sys.executable, "-m", "venv", str(venv)], check=True)
        pip(py, "install", "--quiet", "--upgrade", "pip", "wheel", "setuptools")
    return py


def pip(py: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess:
    cmd = [str(py), "-m", "pip", *args]
    return subprocess.run(cmd, check=check, capture_output=True, text=True)


def target_flags(py_ver: str) -> list[str]:
    """pip flags that make it resolve for Windows even when we run on Linux."""
    short = py_ver.replace(".", "")  # "3.11" -> "311"
    return [
        "--platform", "win_amd64",
        "--python-version", short,
        "--implementation", "cp",
        "--abi", f"cp{short}",
    ]


# --------------------------------------------------------------------------- #
# CPython for Windows
# --------------------------------------------------------------------------- #
def _github_json(url: str) -> dict:
    headers = {"User-Agent": "parsigo-build"}
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    if token:  # raises the API limit from 60/h to 5000/h on CI runners
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=60) as r:  # noqa: S310 — fixed host
        import json

        return json.loads(r.read().decode("utf-8"))


def find_cpython_asset(py_ver: str) -> tuple[str, str]:
    """(name, url) of the stripped, install-only CPython archive."""
    pattern = re.compile(PBS_ASSET.format(ver=re.escape(py_ver)))
    try:
        release = _github_json(f"https://api.github.com/repos/{PBS_REPO}/releases/latest")
        for asset in release.get("assets", []):
            if pattern.fullmatch(asset["name"]):
                log(f"• CPython {py_ver}: {asset['name']}")
                return asset["name"], asset["browser_download_url"]
        reason = f"no matching asset in release {release.get('tag_name')}"
    except Exception as exc:  # noqa: BLE001 — rate limit, proxy, offline
        reason = f"GitHub API unavailable ({exc})"

    fallback = PBS_FALLBACK.get(py_ver)
    if fallback:
        warn(f"{reason}; using the pinned CPython {py_ver} build instead")
        return fallback.rsplit("/", 1)[-1], fallback
    raise SystemExit(
        f"cannot locate a CPython {py_ver} x86_64-pc-windows-msvc build ({reason}). "
        "Try --python-version 3.11, or set GITHUB_TOKEN to lift the API rate limit."
    )


def download(url: str, dest: Path) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 0:
        log(f"• cached: {dest.name}")
        return dest
    log(f"• downloading {dest.name}")
    tmp = dest.with_suffix(dest.suffix + ".part")
    req = urllib.request.Request(url, headers={"User-Agent": "parsigo-build"})
    with urllib.request.urlopen(req, timeout=120) as r, tmp.open("wb") as f:  # noqa: S310
        total = int(r.headers.get("Content-Length") or 0)
        done, tick = 0, time.time()
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
            done += len(chunk)
            if time.time() - tick > 1.0:
                pct = f"{done * 100 // total:3d}%" if total else f"{done >> 20}MB"
                print(f"\r  {pct}", end="", flush=True)
                tick = time.time()
    print(f"\r  {dest.name}: {tmp.stat().st_size / 1e6:.1f} MB", flush=True)
    os.replace(tmp, dest)
    return dest


def unpack_cpython(archive: Path, dest: Path, py_ver: str) -> Path:
    """Extract the archive; python-build-standalone ships a top-level python/."""
    if (dest / "python" / "pythonw.exe").exists():
        return dest / "python"
    log("• unpacking CPython")
    with tarfile.open(archive, "r:gz") as tf:
        if hasattr(tarfile, "data_filter"):
            tf.extractall(dest, filter="data")  # noqa: S202 — trusted asset
        else:
            tf.extractall(dest)  # noqa: S202
    py = dest / "python"
    if not (py / "python.exe").exists():  # defensive: some builds nest differently
        for cand in dest.rglob("python.exe"):
            py = cand.parent
            break
    if not (py / "python.exe").exists():
        raise SystemExit("the CPython archive did not contain python.exe")
    if not (py / "pythonw.exe").exists():
        warn("pythonw.exe missing — the app would show a console window")
    return py


# --------------------------------------------------------------------------- #
# wheels
# --------------------------------------------------------------------------- #
def wheels(cache: Path, py_ver: str) -> Path:
    """Everything in requirements-win.txt as win_amd64 wheels, in one folder."""
    py = tool_python()
    cache.mkdir(parents=True, exist_ok=True)
    flags = target_flags(py_ver)

    def closure() -> subprocess.CompletedProcess:
        return pip(py, "download", "--dest", str(cache), "--only-binary=:all:",
                   "--find-links", str(cache), *flags, "-r", str(REQS), check=False)

    log("• resolving wheels for win_amd64")
    result = closure()
    if result.returncode != 0:
        # a dependency that only ships an sdist: build a universal wheel here
        for name in _sdist_only_candidates(result.stderr + result.stdout):
            log(f"• building a local wheel for {name} (sdist-only)")
            build_universal_wheel(py, name, cache)
            result = closure()
            if result.returncode == 0:
                break
    if result.returncode != 0:
        raise SystemExit("wheel download failed:\n" + (result.stderr or result.stdout)[-3000:])
    return cache


def _sdist_only_candidates(output: str) -> list[str]:
    """Package names pip named in a dependency conflict, minus what we ship."""
    found = re.findall(r"depends on ([\w.\-]+)", output)
    out: list[str] = []
    for name in list(SDIST_ONLY) + found:
        key = name.lower().replace("-", "_")
        if key not in [n.lower().replace("-", "_") for n in out]:
            out.append(name)
    return out


def build_universal_wheel(py: Path, name: str, cache: Path) -> None:
    """sdist -> py3-none-any wheel, using the build venv (needs wheel/setuptools)."""
    with tempfile.TemporaryDirectory() as tmp:
        got = pip(py, "download", "--no-deps", "--no-binary", ":all:", "--dest", tmp, name,
                  check=False)
        if got.returncode != 0:
            raise SystemExit(f"cannot fetch the sdist for {name}:\n{got.stderr[-1500:]}")
        sdists = list(Path(tmp).glob("*.tar.gz")) + list(Path(tmp).glob("*.zip"))
        if not sdists:
            raise SystemExit(f"{name}: no sdist downloaded")
        built = pip(py, "wheel", "--no-deps", "--no-build-isolation",
                    "--wheel-dir", str(cache), str(sdists[0]), check=False)
        if built.returncode != 0:
            raise SystemExit(f"cannot build a wheel for {name}:\n{built.stderr[-1500:]}")


def install_wheels(cache: Path, site_packages: Path, py_ver: str) -> int:
    py = tool_python()
    site_packages.mkdir(parents=True, exist_ok=True)
    log("• installing wheels into python/Lib/site-packages")
    done = pip(py, "install", "--no-index", "--find-links", str(cache), "--target",
               str(site_packages), "--no-deps", "--only-binary=:all:",
               *target_flags(py_ver), "--no-compile", "-r", str(REQS), check=False)
    if done.returncode != 0:
        raise SystemExit("wheel install failed:\n" + (done.stderr or done.stdout)[-3000:])
    return sum(1 for _ in site_packages.iterdir())


def prune_runtime(py_dir: Path) -> None:
    """Drop what a runtime never loads — a standalone CPython ships a lot of it.

    Test suites, the pip/setuptools machinery, the Tcl/Tk GUI toolkit (the
    window is WebView2, not Tk), headers and import libraries. Removing them
    takes the bundle from ~280MB to well under 200MB without touching anything
    the engine or the UI imports.
    """
    log("• pruning the runtime (tests, pip, tk, headers)")
    doomed_dirs = [
        "Lib/test", "Lib/idlelib", "Lib/lib2to3", "Lib/ensurepip", "Lib/tkinter",
        "Lib/site-packages/pip", "Lib/site-packages/setuptools", "Lib/site-packages/wheel",
        "Lib/site-packages/pkg_resources", "Lib/site-packages/_distutils_hack",
        "tcl", "include", "libs",
    ]
    for rel in doomed_dirs:
        shutil.rmtree(py_dir / rel, ignore_errors=True)
    for rel in ("DLLs/_tkinter.pyd", "DLLs/tcl86t.dll", "DLLs/tk86t.dll",
                "Lib/site-packages/distutils-precedence.pth"):
        (py_dir / rel).unlink(missing_ok=True)
    for cache in py_dir.rglob("__pycache__"):
        shutil.rmtree(cache, ignore_errors=True)
    for junk in list(py_dir.rglob("*.pyc")) + list(py_dir.rglob("*.pyo")):
        junk.unlink(missing_ok=True)


# --------------------------------------------------------------------------- #
# app payload
# --------------------------------------------------------------------------- #
SKIP_DIRS = {"__pycache__", ".git", ".venv", "venv", "env", "model", "uploads", "output",
             "dist", ".build-cache", ".hf-cache", "node_modules", ".pytest_cache"}
SKIP_FILES = {"*.pyc", "*.pyo", "*.log", ".DS_Store", "Thumbs.db"}

COPY_ITEMS = ("scripts", "web", "voices", "desktop", "docs",
              "README.md", "README.en.md", "NOTICE.md", "requirements.txt")


def copy_app(dest: Path) -> None:
    log("• copying the application")
    for item in COPY_ITEMS:
        src = ROOT / item
        if not src.exists():
            continue
        if src.is_dir():
            for path in src.rglob("*"):
                if any(part in SKIP_DIRS for part in path.parts):
                    continue
                if path.is_dir():
                    continue
                if any(path.match(p) for p in SKIP_FILES):
                    continue
                out = dest / path.relative_to(ROOT)
                out.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, out)
        else:
            shutil.copy2(src, dest / item)


# --------------------------------------------------------------------------- #
# launcher
# --------------------------------------------------------------------------- #
def find_zig() -> str | None:
    zig = shutil.which("zig")
    if zig:
        return zig
    py = tool_python()
    log("• installing zig (pip package) for the launcher")
    got = pip(py, "install", "--quiet", "ziglang", check=False)
    if got.returncode != 0:
        return None
    root = py.parent.parent  # <venv>/Scripts/python.exe or <venv>/bin/python
    for cand in list(root.rglob("zig.exe")) + list(root.rglob("zig")):
        if not cand.is_file():
            continue
        if os.name == "nt" or cand.stat().st_mode & 0o111:
            return str(cand)
    return None


def find_windres() -> str | None:
    for name in ("windres", "x86_64-w64-mingw32-windres", "llvm-rc"):
        p = shutil.which(name)
        if p and "llvm-rc" not in name:
            return p
    return None


def pe_subsystem(exe: Path) -> int | None:
    """Read the PE optional header Subsystem (2 = GUI, 3 = console)."""
    try:
        data = exe.read_bytes()
        e = struct.unpack_from("<I", data, 0x3C)[0]
        if data[e:e + 4] != b"PE\0\0":
            return None
        return struct.unpack_from("<H", data, e + 24 + 68)[0]
    except Exception:  # noqa: BLE001
        return None


def build_launcher(dest: Path) -> bool:
    zig = find_zig()
    if not zig:
        warn("zig not found — ship the .bat/.vbs launchers instead of Parsigo.exe")
        return False
    obj = None
    windres = find_windres()
    if windres:
        try:
            with tempfile.TemporaryDirectory() as tmp:
                obj = Path(tmp) / "resource.o"
                subprocess.run([windres, "-i", "resource.rc", "-o", str(obj), "-O", "coff"],
                               cwd=WINDOWS, check=True, capture_output=True)  # noqa: S603
                log("• compiled icon + version resource")
                _link(zig, dest, obj)
                return True
        except Exception as exc:  # noqa: BLE001
            warn(f"windres failed ({exc}); building without the icon resource")
            obj = None
    return _link(zig, dest, None)


def _link(zig: str, dest: Path, obj: Path | None) -> bool:
    out = dest / "Parsigo.exe"
    cmd = [zig, "cc", "-target", "x86_64-windows-gnu", "-O2", "-municode",
           "-Wl,--subsystem,windows", "-s", str(WINDOWS / "launcher.c")]
    if obj is not None:
        cmd.append(str(obj))
    cmd += ["-o", str(out)]
    log("• compiling Parsigo.exe (zig cc, ~1 min)")
    done = subprocess.run(cmd, check=False, capture_output=True, text=True)
    if done.returncode != 0:
        warn("launcher build failed:\n" + (done.stderr or done.stdout)[-1200:])
        return False
    if pe_subsystem(out) != 2:
        warn("launcher is not a GUI-subsystem exe — a console may flash")
    log(f"• Parsigo.exe: {out.stat().st_size / 1024:.0f} KB")
    return True


# --------------------------------------------------------------------------- #
# small text files that make a folder shippable
# --------------------------------------------------------------------------- #
READ_FIRST = """پارسی‌گو {ver} — نسخهٔ ویندوز (قابل حمل)
=================================================

۱) این پوشه را جابه‌جا نکنید؛ برنامه از همین مسیر اجرا می‌شود.
   (می‌توانید کل پوشه را به هر جای دیگری هم منتقل کنید، فقط همهٔ
   فایل‌ها باید کنار هم بمانند.)

۲) روی «Parsigo.exe» دوبار کلیک کنید.
   بار اول پنجرهٔ «نصب مدل» باز می‌شود: حدود ۴۷۰ مگابایت دانلود
   یک‌بارهٔ موتور صوتی. بعد از آن، برنامه بدون اینترنت کار می‌کند.

۳) اگر دانلود از huggingface.co مسدود بود، در همان پنجره کادر
   «آینهٔ دانلود» را با https://hf-mirror.com پر کنید، یا دکمهٔ
   «انتخاب پوشهٔ مدل از دیسک» را بزنید و پوشه‌ای که از قبل دارید
   (شامل manifest.json) را انتخاب کنید.

۴) برای ساختن میانبر روی دسکتاپ: روی Make-Shortcut.cmd دوبار کلیک کنید.

۵) داده‌های شما (صداهای بارگذاری‌شده، لاگ، مدل) داخل همین پوشه
   در پوشه‌های data و model می‌مانند — این نسخه «قابل حمل» است،
   یعنی چیزی در ویندوز نصب نمی‌کند.

عیب‌یابی
--------
- پنجره باز نمی‌شود؟ «Parsigo-console.bat» را اجرا کنید تا متن خطا را ببینید،
  یا فایل data\\logs\\app.log را بخوانید.
- WebView2 نصب نیست (ویندوز ۱۰ قدیمی‌تر): «Microsoft Edge WebView2 Runtime»
  را از سایت مایکروسافت نصب کنید. ویندوز ۱۱ از قبل دارد.
- فضای لازم: حدود ۲۰۰ مگابایت برنامه + ۴۷۰ مگابایت مدل.

نسخهٔ {ver} — مدل‌ها: CC-BY-NC-4.0 (غیرتجاری) — جزئیات در NOTICE.md
"""

BAT_LAUNCH = """@echo off
rem Parsigo — launcher fallback (Parsigo.exe does the same thing natively)
start "" "%~dp0python\\pythonw.exe" "%~dp0desktop\\main.py" %*
"""

BAT_CONSOLE = """@echo off
chcp 65001 >nul
set PYTHONUTF8=1
echo Parsigo - console mode (close this window to quit)
"%~dp0python\\python.exe" "%~dp0desktop\\main.py" %*
if errorlevel 1 pause
"""

VBS_LAUNCH = """' Parsigo - start with no console window at all
Dim sh, fso, root, q
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
q = Chr(34)
sh.CurrentDirectory = root
sh.Run q & root & "\\python\\pythonw.exe" & q & " " & q & root & "\\desktop\\main.py" & q, 0, False
"""

SHORTCUT_PS1 = """# Parsigo — create Desktop + Start Menu shortcuts with the app icon.
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$target = Join-Path $root "Parsigo.exe"
if (-not (Test-Path $target)) { $target = Join-Path $root "python\\pythonw.exe" }
$icon = Join-Path $root "desktop\\assets\\parsigo.ico"

$shell = New-Object -ComObject WScript.Shell
foreach ($dir in @([Environment]::GetFolderPath("Desktop"),
                   (Join-Path $env:APPDATA "Microsoft\\Windows\\Start Menu\\Programs"))) {
    $lnkPath = Join-Path $dir "پارسی‌گو.lnk"
    $lnk = $shell.CreateShortcut($lnkPath)
    $lnk.TargetPath = $target
    if ($target -like "*pythonw.exe") { $lnk.Arguments = '"' + (Join-Path $root "desktop\\main.py") + '"' }
    $lnk.WorkingDirectory = $root
    if (Test-Path $icon) { $lnk.IconLocation = $icon }
    $lnk.Description = "پارسی‌گو — تبدیل متن فارسی به گفتار (آفلاین)"
    $lnk.Save()
    Write-Host "ساخته شد: $lnkPath"
}
Write-Host ""
Write-Host "میانبرها ساخته شدند. برای حذف: همین فایل را با -Remove اجرا کنید."
"""

MAKE_SHORTCUT_CMD = """@echo off
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make-shortcut.ps1"
pause
"""


def write_extras(dest: Path) -> None:
    log("• writing launchers and notes")
    (dest / "portable.txt").write_text(
        "This file makes Parsigo keep its model and data inside this folder.\n"
        "Delete it to use %LOCALAPPDATA%\\Parsigo instead (per-user install).\n",
        encoding="utf-8",
    )
    (dest / "README-FIRST.txt").write_text("\ufeff" + READ_FIRST.format(ver=APP_VERSION),
                                          encoding="utf-8")
    (dest / "Parsigo.bat").write_text(BAT_LAUNCH.replace("\n", "\r\n"), encoding="utf-8")
    (dest / "Parsigo-console.bat").write_text(BAT_CONSOLE.replace("\n", "\r\n"), encoding="utf-8")
    (dest / "Parsigo-no-console.vbs").write_text(VBS_LAUNCH.replace("\n", "\r\n"), encoding="utf-8")
    (dest / "make-shortcut.ps1").write_text("\ufeff" + SHORTCUT_PS1, encoding="utf-8")
    (dest / "Make-Shortcut.cmd").write_text(MAKE_SHORTCUT_CMD.replace("\n", "\r\n"),
                                            encoding="utf-8")


def bundle_model(dest: Path, mirror: str) -> None:
    log("• downloading the model package into the build (this is the big one)")
    sys.path.insert(0, str(ROOT))
    os.environ["PARSIGO_MODEL_DIR"] = str(dest / "model")
    from desktop import model_setup

    last = {"pct": -5}

    def show(s: dict) -> None:
        pct = int(s.get("percent") or 0)
        if pct >= last["pct"] + 5:
            last["pct"] = pct
            print(f"\r  {pct:3d}%  {s.get('message', '')[:60]}", end="", flush=True)

    missing = model_setup.download_blocking(mirror=mirror, on_progress=show)
    print()
    if missing:
        raise SystemExit("model incomplete: " + ", ".join(missing[:5]))


def zip_tree(src: Path, out: Path) -> Path:
    log(f"• compressing -> {out.name}")
    if out.exists():
        out.unlink()
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6,
                        strict_timestamps=False) as zf:
        for path in sorted(src.rglob("*")):
            if path.is_file():
                zf.write(path, path.relative_to(src.parent))
    log(f"• {out.name}: {out.stat().st_size / 1e6:.1f} MB")
    return out


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="build the portable Windows app")
    ap.add_argument("--python-version", default="3.11", help="target CPython (3.11 or 3.12)")
    ap.add_argument("--out", type=Path, default=ROOT / "dist", help="output folder")
    ap.add_argument("--with-model", action="store_true",
                    help="bundle the 470MB model (needs huggingface.co access)")
    ap.add_argument("--mirror", default=os.environ.get("HF_ENDPOINT", ""),
                    help="Hugging Face mirror for --with-model")
    ap.add_argument("--no-zip", action="store_true", help="leave the folder, skip the .zip")
    ap.add_argument("--no-launcher", action="store_true", help="skip Parsigo.exe")
    args = ap.parse_args(argv)

    py_ver = args.python_version
    name = f"Parsigo-{APP_VERSION}-windows-x64"
    build = CACHE / f"build-{name}"
    if build.exists():
        shutil.rmtree(build, ignore_errors=True)
    build.mkdir(parents=True, exist_ok=True)
    log(f"Parsigo {APP_VERSION} — portable Windows build ({py_ver}, win_amd64)")

    asset_name, asset_url = find_cpython_asset(py_ver)
    archive = download(asset_url, CACHE / "downloads" / asset_name)
    py_dir = unpack_cpython(archive, build, py_ver)

    cache = wheels(CACHE / f"wheels-cp{py_ver.replace('.', '')}-win_amd64", py_ver)
    count = install_wheels(cache, py_dir / "Lib" / "site-packages", py_ver)
    log(f"• {count} packages installed")
    prune_runtime(py_dir)

    copy_app(build)
    write_extras(build)
    if not args.no_launcher and not build_launcher(build):
        warn("building without Parsigo.exe (the .bat/.vbs launchers still work)")
    if args.with_model:
        bundle_model(build, args.mirror)

    final = args.out / name
    if final.exists():
        shutil.rmtree(final, ignore_errors=True)
    final.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(build), str(final))

    size_mb = sum(f.stat().st_size for f in final.rglob("*") if f.is_file()) / 1e6
    exe = final / "Parsigo.exe"
    log("")
    log(f"✓ {final}  ({size_mb:.0f} MB)")
    log(f"  executable: {exe if exe.exists() else final / 'Parsigo.bat'}")
    if not args.no_zip:
        z = zip_tree(final, args.out / f"{name}.zip")
        log(f"  zip:        {z}")
    log("  next: double-click the exe on any 64-bit Windows 10/11 machine;")
    log("        the first run offers the one-time 470MB model download.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
