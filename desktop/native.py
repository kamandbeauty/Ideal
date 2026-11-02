"""The bridge the web UI calls as ``window.pywebview.api``.

A browser tab cannot do two things a desktop app must: put a file where the
user picks (WebView2 silently ignores ``<a download>`` in many cases) and show
a real first-run installer. Both are exposed here as plain methods; pywebview
serialises the return values to JS for us, so every method returns a
JSON-friendly dict and never raises (errors go back as ``{"error": ...}`` and
are shown in the UI).
"""

from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path

from . import __version__, model_setup, paths


class DesktopBridge:
    def __init__(self, app) -> None:
        self._app = app
        self._downloader = model_setup.ModelDownloader()
        self._started = time.time()

    # ----------------------------------------------------------------- info #
    def status(self) -> dict:
        missing = model_setup.missing_files()
        engine = {}
        srv = self._app.server_module
        if srv is not None:
            engine = dict(getattr(srv, "engine_status", {}) or {})
        return {
            "version": __version__,
            "platform": sys.platform,
            "model_installed": not missing,
            "missing": missing[:10],
            "model_dir": str(paths.model_root()),
            "data_dir": str(paths.data_dir()),
            "model_size": model_setup.installed_size(),
            "portable": paths.is_portable(),
            "base_url": self._app.base_url,
            "engine": engine.get("state", "cold"),
            "engine_error": engine.get("error") or "",
            "uptime": round(time.time() - self._started, 1),
        }

    def app_info(self) -> dict:
        """About-box values; also the handshake that tells setup.html the bridge is live."""
        return {
            "version": __version__,
            "model_installed": model_setup.is_installed(),
            "model_dir": str(paths.model_root()),
            "data_dir": str(paths.data_dir()),
            "onnxruntime": _version_of("onnxruntime"),
            "pywebview": _version_of("webview"),
        }

    # -------------------------------------------------------------- download #
    def download_model(self, mirror: str = "") -> dict:
        if model_setup.is_installed():
            return {"state": "done", "percent": 100.0, "message": "مدل از قبل نصب است"}
        return self._downloader.start(mirror or "")

    def progress(self) -> dict:
        return self._downloader.snapshot()

    def cancel_setup(self) -> dict:
        """Close the installer window (download, if any, ends with the process)."""
        self._app.close_window()
        return {"ok": True}

    def choose_model_folder(self) -> dict:
        """Fallback for a blocked Hugging Face: use a folder the user already has."""
        folder = self._ask_folder()
        if not folder:
            return {"cancelled": True}
        missing = model_setup.adopt_folder(Path(folder))
        if missing:
            return {"ok": False, "error": "این پوشه فایل‌های لازم را ندارد: " + "، ".join(missing[:4])}
        return {"ok": True, "message": "مدل شناسایی شد", "status": self.status()}

    def open_model_folder(self) -> dict:
        return self._open_path(paths.model_root())

    def open_data_folder(self) -> dict:
        return self._open_path(paths.data_dir())

    # ----------------------------------------------------------------- files #
    def save_wav(self, audio_id: str, suggested: str = "parsigo.wav") -> dict:
        srv = self._app.server_module
        if srv is None:
            return {"error": "سرور در دسترس نیست"}
        data = srv.audio_bytes(audio_id)  # type: ignore[attr-defined]
        if not data:
            return {"error": "صدا پیدا نشد — دوباره بسازید"}
        name = _safe_name(suggested or "parsigo.wav")
        target = self._ask_save(name)
        if not target:
            return {"cancelled": True}
        if not str(target).lower().endswith(".wav"):
            target = f"{target}.wav"  # the dialog lets the extension be deleted
        try:
            Path(target).write_bytes(data)
        except OSError as exc:
            return {"error": f"نوشتن فایل ممکن نشد: {exc}"}
        return {"ok": True, "path": str(target)}

    def open_output_file(self, path: str) -> dict:
        return self._open_path(Path(path).parent if path else paths.data_dir())

    # ---------------------------------------------------------------- window #
    def reload_app(self) -> dict:
        self._app.load_app()
        return {"ok": True}

    def open_in_browser(self) -> dict:
        import webbrowser

        webbrowser.open(self._app.base_url)
        return {"ok": True}

    # --------------------------------------------------------------- helpers #
    def _ask_save(self, filename: str) -> str | None:
        window = self._app.window
        try:
            result = window.create_file_dialog(
                _dialog_type("SAVE"), save_filename=filename, file_types=("فایل WAV (*.wav)",)
            )
        except Exception:  # noqa: BLE001 — dialog failure must not lose the audio
            return None
        return _first(result)

    def _ask_folder(self) -> str | None:
        window = self._app.window
        try:
            result = window.create_file_dialog(_dialog_type("FOLDER"), directory=str(paths.data_dir()))
        except Exception:  # noqa: BLE001
            return None
        return _first(result)

    def _open_path(self, p: Path) -> dict:
        p = Path(p)
        p.mkdir(parents=True, exist_ok=True)
        try:
            if paths.is_windows():
                os.startfile(str(p))  # type: ignore[attr-defined]  # noqa: S606
            elif sys.platform == "darwin":
                subprocess.Popen(["open", str(p)])  # noqa: S603,S607
            else:
                subprocess.Popen(["xdg-open", str(p)])  # noqa: S603,S607
            return {"ok": True, "path": str(p)}
        except Exception as exc:  # noqa: BLE001
            return {"error": str(exc), "path": str(p)}


def _dialog_type(name: str) -> int:
    """pywebview 6 moved the dialog constants into a FileDialog enum; the
    module-level SAVE_DIALOG/FOLDER_DIALOG still work but log a deprecation
    warning, which would end up in the user's log file."""
    import webview

    dialog = getattr(webview, "FileDialog", None)
    if dialog is not None:
        return int(getattr(dialog, name))
    return int(getattr(webview, f"{name}_DIALOG"))


def _first(result) -> str | None:
    """pywebview returns str, tuple[str], or (None,) depending on the dialog."""
    if not result:
        return None
    if isinstance(result, (list, tuple)):
        return str(result[0]) if result and result[0] else None
    return str(result)


def _safe_name(name: str) -> str:
    bad = '<>:"/\\|?*'
    cleaned = "".join(ch for ch in name if ch not in bad and ch >= " ").strip()
    cleaned = cleaned or "parsigo.wav"
    if not cleaned.lower().endswith(".wav"):
        cleaned += ".wav"
    return cleaned[:120]


def _version_of(module: str) -> str:
    try:
        import importlib.metadata as md
        from importlib import import_module

        import_module(module)
        return md.version("pywebview" if module == "webview" else module)
    except Exception:  # noqa: BLE001
        return "—"
