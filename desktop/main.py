"""Parsigo — desktop entry point.

    Parsigo.exe            (double-click: window + local server)
    python -m desktop.main --browser        (same, but in the default browser)
    python -m desktop.main --server-only    (the plain demo server, Ctrl+C to stop)

What it does, in order:

1. redirects everything writable to ``%LOCALAPPDATA%\\Parsigo`` (see paths.py)
2. takes a single-instance lock, so a second double-click focuses the window
   instead of starting a second 470MB engine
3. starts the FastAPI demo on a free loopback port — loopback only, so Windows
   never shows a firewall prompt and nothing is exposed on the LAN
4. preloads the ONNX engine in the background while the window paints
5. opens a WebView2 window on it, or the /setup page when the model is missing

Closing the window stops the server: no orphan process left holding the port.
"""

from __future__ import annotations

import argparse
import json
import logging
import logging.handlers
import os
import socket
import sys
import threading
import time
import traceback
from pathlib import Path

from . import __version__, model_setup, paths

log = logging.getLogger("parsigo")


# --------------------------------------------------------------------------- #
# logging / crash reporting
# --------------------------------------------------------------------------- #
def setup_logging(debug: bool = False) -> None:
    paths.ensure_dirs()
    level = logging.DEBUG if debug or os.environ.get("PARSIGO_DEBUG") else logging.INFO
    root = logging.getLogger()
    root.setLevel(level)
    fmt = logging.Formatter("%(asctime)s %(levelname)-7s %(name)s: %(message)s")

    try:
        fh = logging.handlers.RotatingFileHandler(
            paths.logs_dir() / "app.log", maxBytes=1_000_000, backupCount=3, encoding="utf-8"
        )
        fh.setFormatter(fmt)
        root.addHandler(fh)
    except OSError:
        pass

    # pythonw has no stdout; a console build should still see the log
    if sys.stderr is not None:
        sh = logging.StreamHandler(sys.stderr)
        sh.setFormatter(fmt)
        root.addHandler(sh)


def crash_box(title: str, message: str) -> None:
    """Show a fatal error where a windowed app's user will actually see it."""
    log.error("%s: %s", title, message)
    if paths.is_windows():
        try:
            import ctypes

            ctypes.windll.user32.MessageBoxW(  # type: ignore[attr-defined]
                None, message, title, 0x10  # MB_ICONERROR
            )
            return
        except Exception:  # noqa: BLE001
            pass
    print(f"{title}\n{message}", file=sys.stderr)


# --------------------------------------------------------------------------- #
# single instance
# --------------------------------------------------------------------------- #
_lock_handle = None


def acquire_single_instance() -> bool:
    """False when another copy already owns the lock."""
    global _lock_handle
    if paths.is_windows():
        import ctypes

        kernel32 = ctypes.windll.kernel32  # type: ignore[attr-defined]
        handle = kernel32.CreateMutexW(None, False, "Local\\Parsigo.PersianTTS.SingleInstance")
        already = kernel32.GetLastError() == 183  # ERROR_ALREADY_EXISTS
        _lock_handle = handle
        return not already

    # POSIX (dev machines, Linux/macOS builds): the same idea with flock.
    # A *blocked* flock means "already running"; a *failed* open means the
    # data folder is unusable, and then starting anyway beats refusing to run.
    try:
        import fcntl

        f = open(paths.data_dir() / "parsigo.lock", "w", encoding="utf-8")  # noqa: SIM115
    except OSError:
        return True

    try:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        f.close()
        return False

    try:
        f.write(str(os.getpid()))
        f.flush()
    except OSError:
        pass
    _lock_handle = f
    return True


def instance_file() -> Path:
    return paths.data_dir() / "instance.json"


def publish_instance(port: int) -> None:
    """Let a second launch find the running copy even if focusing fails."""
    try:
        instance_file().write_text(
            json.dumps({"port": port, "pid": os.getpid(), "url": f"http://127.0.0.1:{port}"}),
            encoding="utf-8",
        )
    except OSError:
        pass


def hand_over_to_running_copy(title: str) -> None:
    """Focus the existing window; if that fails, open its UI in the browser.

    A double-click that appears to do nothing is the worst outcome for a
    desktop app, so there is always a visible result.
    """
    if focus_existing_window(title):
        return
    url = None
    try:
        url = json.loads(instance_file().read_text(encoding="utf-8")).get("url")
    except (OSError, ValueError):
        url = None
    if url:
        import webbrowser

        webbrowser.open(url)
        return
    crash_box(
        "پارسی‌گو",
        "پارسی‌گو از قبل در حال اجراست.\n\n"
        "پنجرهٔ آن را در نوار وظیفه پیدا کنید (ممکن است پشت پنجره‌های دیگر باشد).",
    )


def focus_existing_window(title: str) -> bool:
    """Bring the running window forward (Windows); else open its URL."""
    if paths.is_windows():
        try:
            import ctypes
            from ctypes import wintypes

            user32 = ctypes.windll.user32  # type: ignore[attr-defined]
            hwnd = user32.FindWindowW(None, title)
            if hwnd:
                user32.ShowWindow(hwnd, 9)  # SW_RESTORE
                user32.SetForegroundWindow(hwnd)
                return True
            _ = wintypes
        except Exception:  # noqa: BLE001
            pass
    return False


# --------------------------------------------------------------------------- #
# server
# --------------------------------------------------------------------------- #
class App:
    """Owns the uvicorn thread and the window; shared with the JS bridge."""

    def __init__(self, host: str, port: int) -> None:
        self.host = host
        self.port = port
        self.base_url = f"http://{host}:{port}"
        self.server_module = None
        self.window = None
        self._uvicorn = None
        self._thread: threading.Thread | None = None

    # -- lifecycle -------------------------------------------------------- #
    def start_server(self) -> None:
        import uvicorn

        _export_paths()
        sys.path.insert(0, str(paths.app_dir() / "scripts"))
        import server as server_module  # noqa: PLC0415 — path set up just above

        self.server_module = server_module
        server_module.configure(data_dir=paths.data_dir())

        config = uvicorn.Config(
            server_module.app,
            host=self.host,
            port=self.port,
            log_level="warning",
            access_log=False,
            loop="asyncio",
        )
        self._uvicorn = uvicorn.Server(config)
        self._thread = threading.Thread(target=self._uvicorn.run, name="uvicorn", daemon=True)
        self._thread.start()
        self._wait_listening()

    def _wait_listening(self, timeout: float = 30.0) -> None:
        deadline = time.time() + timeout
        while time.time() < deadline:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(0.25)
                if s.connect_ex((self.host, self.port)) == 0:
                    log.info("server listening on %s", self.base_url)
                    return
            time.sleep(0.05)
        raise RuntimeError(
            f"سرور روی درگاه {self.port} بالا نیامد.\n"
            f"گزارش خطا: {paths.logs_dir() / 'app.log'}"
        )

    def preload_engine(self) -> None:
        """Load the ONNX graphs while the window is still painting."""
        if self.server_module is None or not model_setup.is_installed():
            return

        def _load() -> None:
            try:
                self.server_module.get_engine()  # type: ignore[attr-defined]
                log.info("engine ready")
            except Exception:  # noqa: BLE001 — surfaced through /api/health
                log.exception("engine failed to load")

        threading.Thread(target=_load, name="engine-preload", daemon=True).start()

    def start_url(self) -> str:
        return self.base_url + ("" if model_setup.is_installed() else "/setup")

    def load_app(self) -> None:
        if self.window is not None:
            try:
                self.window.load_url(self.base_url + "/")
                self.window.set_title(APP_TITLE_WINDOW)
            except Exception:  # noqa: BLE001
                log.exception("load_url failed")

    def close_window(self) -> None:
        if self.window is not None:
            try:
                self.window.destroy()
            except Exception:  # noqa: BLE001
                log.exception("window destroy failed")

    def shutdown(self) -> None:
        if self._uvicorn is not None:
            self._uvicorn.should_exit = True
            if self._thread is not None:
                self._thread.join(timeout=5)
        log.info("stopped")


APP_TITLE_WINDOW = "پارسی‌گو — تبدیل متن فارسی به گفتار"


def _export_paths() -> None:
    """Must happen *before* the engine modules are imported.

    scripts/tts_onnx.py and scripts/g2p_onnx.py resolve the model folder once,
    at import time (PARSIGO_MODEL_DIR), so the environment has to be right the
    first time they are touched — not after.
    """
    os.environ.setdefault("PARSIGO_MODEL_DIR", str(paths.model_root()))
    os.environ.setdefault("PARSIGO_DATA_DIR", str(paths.data_dir()))


# --------------------------------------------------------------------------- #
# window
# --------------------------------------------------------------------------- #
def run_window(app: App, debug: bool) -> None:
    import webview

    from .native import DesktopBridge

    bridge = DesktopBridge(app)
    icon = paths.app_dir() / "desktop" / "assets" / "parsigo.ico"
    window = webview.create_window(
        APP_TITLE_WINDOW,
        url=app.start_url(),
        js_api=bridge,
        width=1180,
        height=880,
        min_size=(880, 620),
        background_color="#0c0e13",
        text_select=True,
    )
    app.window = window

    webview.settings["ALLOW_DOWNLOADS"] = True  # fallback if the bridge is absent
    gui = "edgechromium" if paths.is_windows() else None
    try:
        webview.start(
            debug=debug,
            gui=gui,
            private_mode=False,  # keep localStorage/history between runs
            storage_path=str(paths.data_dir() / "webview"),
            icon=str(icon) if icon.is_file() else None,
        )
    finally:
        app.shutdown()


def run_browser(app: App) -> None:
    import webbrowser

    print(f"پارسی‌گو {__version__} — {app.base_url}")
    print("برای بستن: Ctrl+C")
    webbrowser.open(app.start_url())
    try:
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        app.shutdown()


def run_server_only(app: App, host: str, port: int) -> None:
    _export_paths()
    sys.path.insert(0, str(paths.app_dir() / "scripts"))
    import server as server_module

    server_module.configure(data_dir=paths.data_dir())
    print(f"پارسی‌گو {__version__} — http://{host}:{port}")
    app.server_module = server_module
    server_module.run(host=host, port=port)


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def install_model(mirror: str = "") -> int:
    """`--install-model`: the console twin of the first-run setup window."""
    if model_setup.is_installed():
        print("مدل از قبل نصب است: " + str(paths.model_root()))
        return 0
    print(f"دانلود مدل صوتی در {paths.model_root()} — حدود ۴۷۰ مگابایت")
    print("برای لغو: Ctrl+C")
    last = {"pct": -5}

    def show(state: dict) -> None:
        pct = int(state.get("percent") or 0)
        if pct >= last["pct"] + 2:
            last["pct"] = pct
            print(f"\r  {pct:3d}%  {str(state.get('message', ''))[:56]:<56}", end="", flush=True)

    try:
        missing = model_setup.download_blocking(mirror=mirror, on_progress=show)
    except KeyboardInterrupt:
        print("\nلغو شد.")
        return 130
    except Exception as exc:  # noqa: BLE001
        print(f"\nخطا: {exc}")
        print("راهنما: اگر دسترسی مسدود است از --mirror https://hf-mirror.com استفاده کنید.")
        return 1
    print()
    if missing:
        print("ناقص: " + "، ".join(missing[:6]))
        return 2
    print("✓ مدل نصب شد.")
    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(prog="parsigo", description="پارسی‌گو — فارسی به گفتار، آفلاین")
    p.add_argument("--version", action="version", version=f"Parsigo {__version__}")
    p.add_argument("--browser", action="store_true", help="open in the default browser instead of a window")
    p.add_argument("--server-only", action="store_true", help="run the plain HTTP demo (no window)")
    p.add_argument("--host", default=os.environ.get("PARSIGO_HOST", "127.0.0.1"))
    p.add_argument("--port", type=int, default=int(os.environ.get("PARSIGO_PORT", "0")),
                   help="0 = pick a free port automatically")
    p.add_argument("--debug", action="store_true", help="verbose log + WebView devtools")
    p.add_argument("--install-model", action="store_true",
                   help="download the model package now, with a console progress bar, then exit")
    p.add_argument("--mirror", default=os.environ.get("HF_ENDPOINT", ""),
                   help="Hugging Face mirror for --install-model (e.g. https://hf-mirror.com)")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    try:
        import multiprocessing

        multiprocessing.freeze_support()  # PyInstaller one-file safety
    except Exception:  # noqa: BLE001
        pass

    args = parse_args(argv)
    setup_logging(args.debug)
    paths.ensure_dirs()

    if paths.is_windows():
        try:
            import ctypes

            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("Parsigo.PersianTTS.1")
            ctypes.windll.shcore.SetProcessDpiAwareness(2)  # per-monitor DPI
        except Exception:  # noqa: BLE001
            pass

    log.info("Parsigo %s | app=%s data=%s model=%s portable=%s", __version__,
             paths.app_dir(), paths.data_dir(), paths.model_root(), paths.is_portable())

    if args.install_model:
        return install_model(args.mirror)

    if args.server_only:
        app = App(args.host, args.port or 8000)
        run_server_only(app, args.host, args.port or 8000)
        return 0

    if not acquire_single_instance():
        log.info("another instance owns the lock — handing over")
        hand_over_to_running_copy(APP_TITLE_WINDOW)
        return 0

    port = args.port or paths.free_port(args.host)
    app = App(args.host, port)
    app.start_server()
    publish_instance(port)
    app.preload_engine()

    if args.browser:
        run_browser(app)
        return 0

    try:
        run_window(app, args.debug)
    except Exception as exc:  # noqa: BLE001 — no WebView2 runtime, missing pythonnet…
        log.exception("window failed")
        msg = (
            "پنجرهٔ برنامه باز نشد.\n\n"
            f"{exc}\n\n"
            "اگر Windows 10/11 دارید، «WebView2 Runtime» مایکروسافت را نصب کنید\n"
            "(معمولاً از قبل نصب است) یا برنامه را با گزینهٔ --browser اجرا کنید.\n\n"
            f"نشانی محلی: {app.base_url}\n"
            f"گزارش: {paths.logs_dir() / 'app.log'}"
        )
        crash_box("پارسی‌گو", msg)
        run_browser(app)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception:  # noqa: BLE001
        crash_box("پارسی‌گو — خطای اجرا", traceback.format_exc(limit=6))
        raise SystemExit(1)
