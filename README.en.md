# Parsigo — Windows edition

**Persian text-to-speech with voice cloning, fully offline, on CPU.**

This repository is the **Windows desktop build** of
[`nimaone/persian_tts`](https://github.com/nimaone/persian_tts): the same pure-ONNX engine
(`pocket-tts-farsi-v2` + `Homo-GE2PE-Persian`), wrapped so it behaves like a program instead
of a server: double-click an `.exe`, get a native window, a first-run model installer, a
Windows "Save as…" dialog — and no Python installation required in the portable build.

|  |  |
|---|---|
| OS | Windows 10 (1809+) / 11, 64-bit |
| Runtime | ONNX Runtime on CPU — no GPU, no torch |
| Size | ~200 MB app + ~470 MB model (one-time download) |
| Network | only for the one-time model download; nothing leaves the machine afterwards |

## Quick start

**A. Prebuilt** — download `Parsigo-*-windows-x64.zip` from Releases, extract (not into
`C:\Program Files`), run `Parsigo.exe`. The first launch offers the model download.
`Parsigo-Setup-1.1.0.exe` is the classic per-user installer.

**B. From source, one click** (needs Python 3.10+ 64-bit):

```bat
windows\install.bat
```

Creates `.venv`, installs the light dependency set (~200 MB, no torch), optionally downloads
the model, and adds a Start-Menu/Desktop shortcut. Then `windows\run.bat`.

**C. Build the standalone bundle yourself** (runs on Windows, Linux or macOS — it only
downloads Windows artifacts, never executes them):

```bat
windows\build-portable.bat                 :: -> dist\Parsigo-1.1.0-windows-x64\
windows\build-portable.bat --with-model     :: bundle the model too (fully offline)
windows\build-installer.bat                :: -> dist\Parsigo-Setup-1.1.0.exe
```

The same command runs in CI: `.github/workflows/windows.yml`.

**Full guide (Persian): [`docs/WINDOWS.md`](docs/WINDOWS.md).**

## What changed for Windows

* Native WebView2 window over the existing UI; closing it stops the server (no orphan process).
* In-app model installer with progress, speed, `hf-mirror.com` mirror support and "use a model
  folder I already have" — instead of `hf download` in a terminal.
* Native "Save as…" dialog for WAV output.
* Correct Windows paths: read-only code, data in `%LOCALAPPDATA%\Parsigo`; a `portable.txt`
  marker keeps everything inside the app folder for USB/shared machines.
* Single instance (second double-click raises the existing window), loopback-only server
  (no firewall prompt).
* Actionable Persian errors instead of tracebacks: model missing / model incomplete /
  engine failed — plus a `/api/health` endpoint the UI polls.
* `Parsigo.exe` launcher cross-compiled with `zig cc` (`windows/launcher.c`), bundled
  standalone CPython + `win_amd64` wheels, GUI subsystem so no console flashes.
* Two small upstream fixes: the bundled Vazirmatn font now loads (it was 404ing because
  `fonts/` was never mounted), and `scripts/server.py` no longer crashes at import when the
  model is absent.

The engine, phonemisation, chunking, pause model and API are unchanged.

## Layout

```
desktop/    desktop shell: window, model installer, paths, JS↔Python bridge
scripts/    engine + FastAPI server (upstream, patched for paths/model-when-missing)
web/        Persian RTL UI (upstream + a status bar)
windows/    install.bat/.ps1, build_portable.py, launcher.c, installer.iss, CI helpers
docs/       WINDOWS.md + engine notes (upstream docs in docs/upstream/)
```

## Credits & licences

See [`NOTICE.md`](NOTICE.md). The Persian TTS model is released under **CC-BY-NC-4.0** —
non-commercial use only; the phonemiser is MIT; Vazirmatn is SIL OFL 1.1.
