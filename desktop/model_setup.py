"""First-run model installer (~470MB, downloaded once, then fully offline).

The Windows build ships without the ONNX package: it is far too big for a
repository, so the app fetches it the first time it starts and keeps it under
``%LOCALAPPDATA%\\Parsigo\\model`` (or next to the exe in a portable copy).

Two sources are used, because the runtime needs files from both:

``Nimaone/pocket-tts-farsi-v2-onnx``
    the exported graphs (``model/onnx/*.onnx``, ``weights.npz``,
    ``decode_state_init.npz``, ``manifest.json``)
``mehdi-hf/pocket-tts-farsi-v2``
    ``tokenizer_ph.model`` (sentencepiece) and ``normalize_fa.py`` (Persian
    text normalisation). Whether a given ONNX upload already carries these
    depends on how it was exported, so the downloader accepts them either
    place and copies them into ``model/v2`` where the engine looks.

``HF_ENDPOINT`` / the ``mirror`` argument point the download at a Hugging Face
mirror (``https://hf-mirror.com``), which is how users behind a block reach
the model. ``HfApi`` is imported lazily so the app still starts (and can use
an already-downloaded or hand-picked model folder) with no network library.
"""

from __future__ import annotations

import os
import shutil
import threading
import time
from pathlib import Path
from collections.abc import Callable

from . import paths

ONNX_REPO = "Nimaone/pocket-tts-farsi-v2-onnx"
V2_REPO = "mehdi-hf/pocket-tts-farsi-v2"
V2_FILES = ("tokenizer_ph.model", "normalize_fa.py")

# exactly what scripts/tts_onnx.py and scripts/g2p_onnx.py open at runtime
REQUIRED_ONNX = (
    "manifest.json",
    "flow_lm_step.onnx",
    "mimi_encoder.onnx",
    "mimi_decoder_step_kv.onnx",
    "g2p_encoder.onnx",
    "g2p_decoder.onnx",
    "weights.npz",
    "decode_state_init.npz",
)

# weights above 2GB are written to a sidecar by torch.onnx; it is part of the
# package when present, so it is required only if an .onnx file asks for it
SIDECAR_SUFFIXES = (".data", ".onnx.data")

Progress = Callable[[dict], None]


# --------------------------------------------------------------------------- #
# validation
# --------------------------------------------------------------------------- #
def missing_files() -> list[str]:
    """Human-readable list of what is still absent, in engine terms."""
    miss: list[str] = []
    onnx = paths.onnx_dir()
    for name in REQUIRED_ONNX:
        if not (onnx / name).is_file():
            miss.append(f"model/onnx/{name}")
    v2 = paths.v2_dir()
    for name in V2_FILES:
        if not (v2 / name).is_file():
            miss.append(f"model/v2/{name}")
    return miss


def is_installed() -> bool:
    return not missing_files()


def installed_size() -> int:
    total = 0
    for root in (paths.onnx_dir(), paths.v2_dir()):
        if not root.is_dir():
            continue
        for f in root.rglob("*"):
            try:
                if f.is_file():
                    total += f.stat().st_size
            except OSError:
                pass
    return total


# --------------------------------------------------------------------------- #
# accepting a folder the user already has
# --------------------------------------------------------------------------- #
def adopt_folder(src: Path, move: bool = False) -> list[str]:
    """Take a folder the user picked and lay it out where the engine expects.

    Accepts any of the plausible shapes people end up with:

    * the ONNX package itself (``manifest.json`` at the top)
    * a Hugging Face clone (``model/onnx`` / ``onnx`` inside)
    * a whole ``model`` folder (``onnx`` + ``v2``)

    Returns the list of what is still missing afterwards ([] means ready).
    """
    src = Path(src)
    if not src.exists():
        return ["مسیر انتخاب‌شده وجود ندارد"]

    onnx_src = _find_dir_with(src, "manifest.json")
    v2_src = _find_dir_with(src, "tokenizer_ph.model")

    target_onnx = paths.onnx_dir()
    target_v2 = paths.v2_dir()
    target_onnx.mkdir(parents=True, exist_ok=True)
    target_v2.mkdir(parents=True, exist_ok=True)

    if onnx_src is not None and onnx_src.resolve() != target_onnx.resolve():
        for f in onnx_src.iterdir():
            if f.is_file():
                _place(f, target_onnx / f.name, move)

    if v2_src is not None:
        for f in v2_src.iterdir():
            if f.is_file() and f.suffix in {".model", ".py", ".json", ".yaml"}:
                _place(f, target_v2 / f.name, move)

    return missing_files()


def _find_dir_with(root: Path, filename: str, depth: int = 3) -> Path | None:
    """Breadth-first search for the folder holding ``filename``.

    Depth is bounded: the point is to skip the ``model/onnx`` vs ``onnx``
    naming drift, not to walk an entire drive.
    """
    level = [root]
    for _ in range(depth + 1):
        nxt: list[Path] = []
        for d in level:
            try:
                if (d / filename).is_file():
                    return d
            except OSError:
                continue
            try:
                nxt.extend(p for p in d.iterdir() if p.is_dir() and not p.name.startswith("."))
            except OSError:
                continue
        level = nxt
        if not level:
            break
    return None


def _place(src: Path, dst: Path, move: bool) -> None:
    if dst.exists() and dst.stat().st_size == src.stat().st_size:
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    tmp = dst.with_name(dst.name + ".part")
    if move:
        shutil.move(str(src), str(tmp))
    else:
        shutil.copyfile(src, tmp)
    os.replace(tmp, dst)


# --------------------------------------------------------------------------- #
# downloading
# --------------------------------------------------------------------------- #
class ModelDownloader:
    """One background download at a time, with progress the UI can poll."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._thread: threading.Thread | None = None
        self.state: dict = {"state": "idle", "percent": 0.0, "message": "", "detail": ""}

    # -- public API ------------------------------------------------------- #
    def start(self, mirror: str = "") -> dict:
        with self._lock:
            if self._thread and self._thread.is_alive():
                return self.snapshot()
            self.state = {
                "state": "starting", "percent": 0.0, "message": "آماده‌سازی دانلود…",
                "detail": "", "done_bytes": 0, "total_bytes": 0,
            }
            self._thread = threading.Thread(
                target=self._run, args=(mirror.strip(),), name="model-download", daemon=True
            )
            self._thread.start()
        return self.snapshot()

    def snapshot(self) -> dict:
        with self._lock:
            return dict(self.state)

    @property
    def busy(self) -> bool:
        return bool(self._thread and self._thread.is_alive())

    # -- internals -------------------------------------------------------- #
    def _set(self, **kw) -> None:
        with self._lock:
            self.state.update(kw)

    def _run(self, mirror: str) -> None:
        try:
            if mirror:
                os.environ["HF_ENDPOINT"] = mirror
                try:  # already-imported constant would otherwise win
                    import huggingface_hub.constants as hf_constants

                    hf_constants.ENDPOINT = mirror.rstrip("/")
                except Exception:  # noqa: BLE001 — not imported yet: env is enough
                    pass
            self._download_all()
            missing = missing_files()
            if missing:
                self._set(
                    state="error",
                    message="فایل‌های مدل کامل نیستند",
                    detail="این فایل‌ها پیدا نشدند: " + "، ".join(missing[:6]),
                )
                return
            self._set(state="done", percent=100.0, message="مدل با موفقیت نصب شد")
        except Exception as exc:  # noqa: BLE001 — the UI must show *any* failure
            self._set(state="error", message="دانلود مدل ناموفق بود", detail=_explain(exc))

    def _download_all(self) -> None:
        # Windows needs admin rights for symlinks; let the cache copy instead
        # of printing that warning above the progress bar
        os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")
        try:
            from huggingface_hub import HfApi, hf_hub_download
        except ImportError as exc:  # pragma: no cover - dependency is pinned
            raise RuntimeError(
                "کتابخانهٔ huggingface_hub نصب نیست: pip install huggingface_hub"
            ) from exc

        api = HfApi()
        self._set(state="listing", message="دریافت فهرست فایل‌ها از Hugging Face…")

        jobs: list[tuple[str, str, int]] = []  # (repo, filename, size)
        for repo, needed in ((ONNX_REPO, None), (V2_REPO, V2_FILES)):
            try:
                info = api.model_info(repo, files_metadata=True)
            except Exception as exc:  # noqa: BLE001
                raise RuntimeError(f"دسترسی به {repo} ممکن نشد: {exc}") from exc
            for sib in info.siblings or []:
                name = sib.rfilename
                if name.startswith(".") or name.endswith((".md", ".gitattributes")):
                    continue
                if needed is not None and name not in needed:
                    continue
                if needed is None and name in V2_FILES:
                    continue  # grabbed from the v2 repo below, same bytes
                jobs.append((repo, name, int(sib.size or 0)))

        total = sum(size for _, _, size in jobs)
        self._set(total_bytes=total)
        onnx_dir = paths.onnx_dir()
        v2_dir = paths.v2_dir()
        onnx_dir.mkdir(parents=True, exist_ok=True)
        v2_dir.mkdir(parents=True, exist_ok=True)

        done = 0
        for repo, name, size in jobs:
            target_dir = onnx_dir if repo == ONNX_REPO else onnx_dir / "_v2"
            self._set(
                state="downloading",
                message=f"در حال دانلود: {Path(name).name}",
                detail=f"{_mb(done)} از {_mb(total)} مگابایت",
            )
            local = hf_hub_download(
                repo_id=repo,
                filename=name,
                local_dir=str(target_dir),
                # keep the cache inside our model folder, not a second copy
                # in %USERPROFILE%\.cache\huggingface
                cache_dir=str(target_dir / ".hf-cache"),
            )
            done += size or _size_of(local)
            pct = (done / total * 100.0) if total else 0.0
            self._set(
                percent=min(99.0, pct), done_bytes=done,
                detail=f"{_mb(done)} از {_mb(total)} مگابایت",
            )

        self._set(state="finishing", message="جابه‌جایی فایل‌ها…", percent=99.5)
        _flatten_onnx(onnx_dir)
        _flatten_v2(onnx_dir / "_v2", v2_dir)
        _drop_cache(onnx_dir)


def _flatten_onnx(onnx_dir: Path) -> None:
    """hf_hub_download keeps the repo's subfolders; the engine wants them flat."""
    for f in list(onnx_dir.rglob("*")):
        if f.is_file() and f.parent != onnx_dir and not f.name.startswith("."):
            if ".hf-cache" in f.parts:
                continue
            dst = onnx_dir / f.name
            if not dst.exists():
                shutil.move(str(f), str(dst))


def _flatten_v2(staging: Path, v2_dir: Path) -> None:
    if not staging.is_dir():
        return
    for f in staging.rglob("*"):
        if f.is_file() and not f.name.startswith("."):
            dst = v2_dir / f.name
            if not dst.exists():
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(f), str(dst))
    shutil.rmtree(staging, ignore_errors=True)


def _drop_cache(onnx_dir: Path) -> None:
    """hf_hub_download hardlinks out of its cache, so deleting the cache after
    the copy reclaims space without touching a single model file."""
    shutil.rmtree(onnx_dir / ".hf-cache", ignore_errors=True)


def _size_of(p: str | Path) -> int:
    try:
        return Path(p).stat().st_size
    except OSError:
        return 0


def _mb(n: int) -> str:
    return f"{n / (1024 * 1024):.0f}"


def _explain(exc: Exception) -> str:
    """Turn a network traceback into something a user can act on."""
    text = str(exc)
    low = text.lower()
    if "timed out" in low or "timeout" in low:
        return "زمان اتصال به پایان رسید. اینترنت را بررسی کنید یا از آینه (mirror) استفاده کنید."
    if "connect" in low or "getaddrinfo" in low or "name or service" in low:
        return (
            "اتصال به huggingface.co برقرار نشد. اگر دسترسی مسدود است، در کادر آینه "
            "https://hf-mirror.com را وارد کنید یا پوشهٔ مدل را دستی انتخاب کنید."
        )
    if "no space" in low:
        return "فضای دیسک کافی نیست — حدود ۵۵۰ مگابایت فضای آزاد لازم است."
    return text if len(text) < 400 else text[:400] + "…"


def download_blocking(mirror: str = "", on_progress: Progress | None = None,
                      poll: float = 1.0) -> list[str]:
    """Synchronous install, for `windows/build_portable.py --with-model`.

    Returns the list of files still missing ([] on success) and raises
    RuntimeError with the downloader's own message on failure, so a build
    script never reports "done" for a half-copied model.
    """
    worker = ModelDownloader()
    worker.start(mirror)
    while worker.busy:
        if on_progress is not None:
            on_progress(worker.snapshot())
        time.sleep(poll)
    state = worker.snapshot()
    if state.get("state") == "error":
        raise RuntimeError(f"{state.get('message', 'download failed')}: {state.get('detail', '')}")
    return missing_files()


def wait_until_installed(timeout: float = 0.0) -> bool:
    deadline = time.time() + timeout if timeout else None
    while deadline is None or time.time() < deadline:
        if is_installed():
            return True
        time.sleep(0.25)
    return is_installed()
