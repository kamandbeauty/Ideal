"""Where the app lives and where it is allowed to write.

A Windows install is not a git checkout: the code may sit in a read-only
folder (``C:\\Program Files\\Parsigo``) and the current working directory is
whatever Explorer felt like — a shortcut's "Start in" field. So the app never
derives paths from ``os.getcwd()`` and never writes next to its code unless
the user asked for a portable copy.

Resolution order
----------------
code / bundled resources
    ``PARSIGO_APP_DIR`` -> the frozen exe's folder (PyInstaller ``_MEIPASS``
    for bundled data) -> the checkout root (parent of ``desktop/``).

writable data (uploads, generated WAVs, logs)
    ``PARSIGO_DATA_DIR`` -> ``<app>/data`` when ``portable.txt`` sits next to
    the exe (USB stick, shared PC) -> ``%LOCALAPPDATA%\\Parsigo``.

model package (``model/onnx`` + ``model/v2``, ~470MB, downloaded once)
    ``PARSIGO_MODEL_DIR`` -> ``<app>/model`` for portable copies ->
    ``%LOCALAPPDATA%\\Parsigo\\model``.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

APP_NAME = "Parsigo"
APP_TITLE = "پارسی‌گو"


def _frozen() -> bool:
    return bool(getattr(sys, "frozen", False))


def _env_path(name: str) -> Path | None:
    raw = os.environ.get(name, "").strip().strip('"')
    return Path(raw).expanduser() if raw else None


def app_dir() -> Path:
    """Root of the application (scripts/, web/, voices/, desktop/)."""
    env = _env_path("PARSIGO_APP_DIR")
    if env:
        return env
    if _frozen():
        # onedir build: data files live in _MEIPASS (== <exe>/_internal)
        return Path(getattr(sys, "_MEIPASS", Path(sys.executable).parent))
    return Path(__file__).resolve().parent.parent


def exe_dir() -> Path:
    """Folder the user sees — where ``portable.txt`` is looked up."""
    if _frozen():
        return Path(sys.executable).parent
    return app_dir()


def is_portable() -> bool:
    if os.environ.get("PARSIGO_PORTABLE") == "1":
        return True
    try:
        return (exe_dir() / "portable.txt").is_file()
    except OSError:  # unreadable drive — pretend it is a normal install
        return False


def data_dir() -> Path:
    env = _env_path("PARSIGO_DATA_DIR")
    if env:
        return env
    if is_portable():
        return app_dir() / "data"
    if os.name == "nt":
        base = os.environ.get("LOCALAPPDATA") or os.environ.get("APPDATA")
        if base:
            return Path(base) / APP_NAME
        return Path.home() / "AppData" / "Local" / APP_NAME
    base = os.environ.get("XDG_DATA_HOME")
    return (Path(base) if base else Path.home() / ".local" / "share") / APP_NAME.lower()


def model_root() -> Path:
    """Folder that holds ``onnx/`` and ``v2/``."""
    env = _env_path("PARSIGO_MODEL_DIR")
    if env:
        return env
    if is_portable():
        return app_dir() / "model"
    return data_dir() / "model"


def onnx_dir() -> Path:
    return model_root() / "onnx"


def v2_dir() -> Path:
    return model_root() / "v2"


def logs_dir() -> Path:
    return data_dir() / "logs"


def ensure_dirs() -> None:
    for p in (data_dir(), logs_dir(), data_dir() / "uploads" / "voices", data_dir() / "output"):
        p.mkdir(parents=True, exist_ok=True)


def web_dir() -> Path:
    return app_dir() / "web"


def voices_dir() -> Path:
    return app_dir() / "voices"


def is_windows() -> bool:
    return os.name == "nt"


def free_port(host: str = "127.0.0.1") -> int:
    """An unused loopback port — two copies of the app never fight over 8000."""
    import socket

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((host, 0))
        return int(s.getsockname()[1])
