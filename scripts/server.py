# Demo web server for the pure-ONNX Persian TTS engine.
#
#   ./env/Scripts/python.exe scripts/server.py     -> http://127.0.0.1:8000
#
# Endpoints:
#   GET  /                  the single-page UI (web/index.html)
#   GET  /api/voices        available reference voices (builtin + uploaded)
#   POST /api/tts           {text, voice} -> {id, phonemes, duration, ...}
#   GET  /api/audio/{id}    generated WAV
#   POST /api/voice/upload  upload a custom voice (auto-trimmed to 5 s)
import io
import json
import os
import re
import sys
import threading
import time
import uuid
from pathlib import Path

import numpy as np
import soundfile as sf
import uvicorn
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import FileResponse, Response
from pydantic import BaseModel

BASE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE / "scripts"))

# ---- where things live ----------------------------------------------------
# A Windows install keeps the code read-only (Program Files) and puts the
# model + uploads under %LOCALAPPDATA%\Parsigo. desktop/paths.py sets these
# two variables before importing this module; a bare `python scripts/server.py`
# falls back to the checkout, exactly like the original demo.
MODEL_DIR = Path(os.environ.get("PARSIGO_MODEL_DIR") or (BASE / "model"))
DATA_DIR = Path(os.environ.get("PARSIGO_DATA_DIR") or BASE)

WEB_DIR = BASE / "web"
WEB = WEB_DIR / "index.html"
SETUP = BASE / "desktop" / "setup.html"
UPLOAD_DIR = DATA_DIR / "uploads" / "voices"
try:
    # a bare `python scripts/server.py` inside a read-only folder must still
    # start: voice upload is the only thing that needs this directory
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
except OSError:
    pass

try:  # version lives with the desktop shell; keep the server usable without it
    if str(BASE) not in sys.path:
        sys.path.insert(0, str(BASE))
    from desktop import __version__ as APP_VERSION
except Exception:  # noqa: BLE001
    APP_VERSION = "server"

MAX_TEXT = 800          # keep demo requests bounded
MAX_PHONEMES = 2400     # editable manual-phoneme input cap
MAX_VOICES = 64

# required model files — mirrors desktop/model_setup.py REQUIRED_ONNX; kept
# separate so the server has no dependency on the desktop package
REQUIRED_ONNX = (
    "manifest.json", "flow_lm_step.onnx", "mimi_encoder.onnx",
    "mimi_decoder_step_kv.onnx", "g2p_encoder.onnx", "g2p_decoder.onnx",
    "weights.npz", "decode_state_init.npz",
)
REQUIRED_V2 = ("tokenizer_ph.model", "normalize_fa.py")


def missing_model_files() -> list[str]:
    """What the engine would fail on right now, as paths a user can look at."""
    miss = [f"model/onnx/{n}" for n in REQUIRED_ONNX if not (MODEL_DIR / "onnx" / n).is_file()]
    miss += [f"model/v2/{n}" for n in REQUIRED_V2 if not (MODEL_DIR / "v2" / n).is_file()]
    return miss


def model_ready() -> bool:
    return not missing_model_files()


# engine lifecycle, reported to the UI so it can say "loading" instead of
# hanging on a first request that takes ~4 s
engine_status: dict = {"state": "cold", "error": "", "since": None}


def _set_engine_status(state: str, error: str = "") -> None:
    engine_status.update(state=state, error=error, since=time.time())

BUILTIN_VOICE_META = {
    "male_hello.wav": ("آقا · صمیمی", "صدای مرد، لحن آرام و دوستانه"),
    "female_narration.wav": ("بانو · روایت", "صدای زن، روایت‌گر"),
    "male_news.wav": ("آقا · خبری", "صدای مرد، لحن خبرگزاری"),
}

app = FastAPI(title="پارسی‌گو — Persian TTS demo")

# The demo used to serve only index.html, so the bundled Vazirmatn font (and
# the logo) 404'd and Persian text fell back to Segoe UI. Mounting the asset
# folders fixes the typography the UI was designed around.
from fastapi.staticfiles import StaticFiles  # noqa: E402

if (WEB_DIR / "fonts").is_dir():
    app.mount("/fonts", StaticFiles(directory=str(WEB_DIR / "fonts")), name="fonts")
if WEB_DIR.is_dir():
    app.mount("/web", StaticFiles(directory=str(WEB_DIR)), name="web")

_engine = None
_engine_lock = threading.Lock()
_audio_store: dict[str, dict] = {}
_store_lock = threading.Lock()

# punctuation-aware phrase splitting and the pause lengths live with the
# engine (single source of truth for where pauses fall and how long they
# last): PAUSE_S is the sentence-final pause — a real reader stops at a
# period, not just breathes (comma is 0.16 in the engine)
from tts_onnx import SENTENCE_GAP as PAUSE_S, plan_phrases, pack_phrases  # noqa: E402

# The model's audio format, read lazily from the same manifest key the engine
# reads — a future model with a different rate flows through the resample/pause
# math here instead of silently writing wrong-rate WAVs. Reading it lazily is
# what lets the app start (and show its installer) before the 470MB package is
# on disk; deliberately still the static manifest, never get_engine(), so a
# voice upload never triggers a full engine load.
DEFAULT_SR = 24_000
SR: int = DEFAULT_SR
_sr_loaded = False


def _ensure_sr() -> int:
    global SR, _sr_loaded
    if _sr_loaded:
        return SR
    manifest = MODEL_DIR / "onnx" / "manifest.json"
    if manifest.is_file():
        try:
            SR = int(json.loads(manifest.read_text(encoding="utf-8"))["constants"]["sample_rate"])
        except Exception:  # noqa: BLE001 — a damaged manifest must not break uploads
            SR = DEFAULT_SR
    _sr_loaded = True
    return SR


def require_model() -> None:
    """503 + an actionable Persian message instead of a stack trace."""
    miss = missing_model_files()
    if miss:
        raise HTTPException(
            503,
            "مدل صوتی نصب نشده است. صفحهٔ «/setup» را باز کنید یا پوشهٔ مدل را در تنظیمات انتخاب کنید."
            f" (ناقص: {len(miss)} فایل)",
        )


def get_engine():
    global _engine
    if _engine is None:
        require_model()
        _set_engine_status("loading")
        try:
            _ensure_sr()
            from tts_onnx import OnnxTts

            _engine = OnnxTts()
            if not hasattr(_engine, "_g2p"):
                from g2p_onnx import OnnxG2P

                _engine._g2p = OnnxG2P(_engine.dir)
        except HTTPException:
            raise
        except Exception as exc:  # noqa: BLE001
            # a corrupt/mismatched package must read as a diagnosable message,
            # not as a blank 500 in the window
            _set_engine_status("error", f"{type(exc).__name__}: {exc}")
            raise HTTPException(
                503, f"موتور صوتی بالا نیامد: {type(exc).__name__}: {exc}"[:400]
            ) from exc
        _set_engine_status("ready")
    return _engine


def audio_bytes(audio_id: str) -> bytes | None:
    """The generated WAV, for the desktop shell's native "Save as…" dialog."""
    with _store_lock:
        item = _audio_store.get(audio_id)
    return item["wav"] if item else None



def split_sentences(text: str) -> list[str]:
    parts = re.split(r"(?<=[.!؟])\s+", text.strip())
    return [p.strip() for p in parts if p.strip()]


def list_voices() -> list[dict]:
    out = []
    for f in sorted((BASE / "voices").glob("*.wav")):
        name, desc = BUILTIN_VOICE_META.get(f.name, (f.stem, ""))
        out.append({"id": f.name, "name": name, "desc": desc, "builtin": True})
    for f in sorted(UPLOAD_DIR.glob("*.wav")):
        out.append({
            "id": f"upload:{f.name}", "name": f.name[:22],
            "desc": "صدای بارگذاری‌شده", "builtin": False,
        })
    return out[:MAX_VOICES]


def voice_path(voice_id: str) -> Path:
    if voice_id.startswith("upload:"):
        p = UPLOAD_DIR / Path(voice_id[7:]).name
    else:
        p = BASE / "voices" / Path(voice_id).name
    if not p.is_file():
        raise HTTPException(404, "voice not found")
    return p


class TTSRequest(BaseModel):
    text: str
    voice: str
    pace: float = 1.0
    mode: str = "split"   # split: pause at every punctuation | pack: long breaths


class PhonemizeRequest(BaseModel):
    text: str
    mode: str = "split"


class PhonemeTTSRequest(BaseModel):
    phonemes: str
    voice: str
    pace: float = 1.0


@app.get("/")
def index():
    return FileResponse(WEB, headers={"Cache-Control": "no-store"})


@app.get("/setup")
def setup_page():
    """First-run installer — served from here so it works without file:// access."""
    if not SETUP.is_file():
        raise HTTPException(404, "setup page missing")
    return FileResponse(SETUP, headers={"Cache-Control": "no-store"})


@app.get("/logo.png")
@app.get("/favicon.ico")
def logo():
    p = WEB_DIR / "logo.png"
    if not p.is_file():
        raise HTTPException(404)
    return FileResponse(p, media_type="image/png")


@app.get("/api/health")
def health():
    """Bootstrap for the UI and the desktop shell: model + engine state."""
    miss = missing_model_files()
    return {
        "ok": True,
        "version": APP_VERSION,
        "model": {"installed": not miss, "missing": miss[:10], "dir": str(MODEL_DIR)},
        "engine": dict(engine_status),
        "data_dir": str(DATA_DIR),
        "sample_rate": _ensure_sr(),
    }


@app.post("/api/preload")
def preload():
    """Start loading the engine without blocking the window from painting."""
    if not model_ready():
        return {"ok": False, "reason": "model-missing"}
    if engine_status.get("state") in ("loading", "ready"):
        return {"ok": True, "state": engine_status.get("state")}

    def _load() -> None:
        try:
            get_engine()
        except Exception:  # noqa: BLE001 — reported through /api/health
            pass

    threading.Thread(target=_load, name="engine-preload", daemon=True).start()
    return {"ok": True, "state": "loading"}


@app.get("/api/voices")
def voices():
    return {"voices": list_voices()}


@app.get("/api/config")
def config():
    """UI bootstrap values — the text cap lives here, not hardcoded in the HTML."""
    return {"max_text": MAX_TEXT, "max_phonemes": MAX_PHONEMES}


@app.post("/api/phonemize")
def phonemize(req: PhonemizeRequest):
    """Convert Persian text to editable phonemes without generating audio."""
    text = req.text.strip()
    if not text:
        raise HTTPException(400, "متن خالی است")
    if len(text) > MAX_TEXT:
        raise HTTPException(400, f"متن طولانی است (حداکثر {MAX_TEXT} نویسه)")
    if req.mode not in ("split", "pack"):
        raise HTTPException(400, "حالت گفتار باید split یا pack باشد")

    engine = get_engine()
    phonemes_all = []
    with _engine_lock:
        for sent in split_sentences(text):
            try:
                plan = plan_phrases(sent, engine._g2p, engine.sp)
            except ValueError as e:
                raise HTTPException(400, "متن فارسی معتبری پیدا نشد") from e
            if req.mode == "pack":
                plan = pack_phrases(plan)
            phonemes_all.extend(p.replace("1", "") for p, _ in plan)

    phonemes = " ".join(phonemes_all).strip()
    if not phonemes:
        raise HTTPException(400, "فونمی تولید نشد")
    return {"phonemes": phonemes}


@app.post("/api/tts-phonemes")
def tts_phonemes(req: PhonemeTTSRequest):
    """Generate speech directly from a user-edited phoneme string."""
    phonemes = req.phonemes.strip()
    if not phonemes:
        raise HTTPException(400, "فونم خالی است")
    if len(phonemes) > MAX_PHONEMES:
        raise HTTPException(400, f"فونم طولانی است (حداکثر {MAX_PHONEMES} نویسه)")
    if any("\u0600" <= ch <= "\u06FF" for ch in phonemes):
        raise HTTPException(400, "در کادر فونم فقط فونم لاتین وارد کنید؛ متن فارسی را در کادر متن بنویسید")

    engine = get_engine()
    pace = float(min(max(req.pace, 0.6), 1.5))
    with _engine_lock:
        audio = engine.synthesize(phonemes, voice_path(req.voice), pace=pace)

    if len(audio) == 0:
        raise HTTPException(400, "صوتی تولید نشد")
    duration = len(audio) / SR
    buf = io.BytesIO()
    sf.write(buf, audio, SR, format="WAV")
    audio_id = uuid.uuid4().hex[:12]
    with _store_lock:
        _audio_store[audio_id] = {
            "wav": buf.getvalue(),
            "text": phonemes,
            "voice": req.voice,
            "duration": duration,
            "phonemes": phonemes,
        }
    return {
        "id": audio_id,
        "phonemes": phonemes,
        "duration": round(duration, 2),
        "pace": pace,
        "mode": "manual-phonemes",
        "sentences": 1,
        "elapsed": None,
    }


@app.post("/api/tts")
def tts(req: TTSRequest):
    text = req.text.strip()
    if not text:
        raise HTTPException(400, "متن خالی است")
    if len(text) > MAX_TEXT:
        raise HTTPException(400, f"متن طولانی است (حداکثر {MAX_TEXT} نویسه)")

    engine = get_engine()
    pace = float(min(max(req.pace, 0.6), 1.5))
    if req.mode not in ("split", "pack"):
        raise HTTPException(400, "حالت گفتار باید split یا pack باشد")
    phonemes_all, chunks = [], []

    with _engine_lock:
        for sent in split_sentences(text):
            # punctuation-aware plan: each phrase (comma/dash/colon-delimited)
            # is a pause unit with its own gap, and short lead-ins ending in
            # strong punctuation ("سؤال اصلی:") stay standalone
            try:
                plan = plan_phrases(sent, engine._g2p, engine.sp)
            except ValueError as e:
                raise HTTPException(400, "متن فارسی معتبری پیدا نشد") from e
            if req.mode == "pack":
                plan = pack_phrases(plan)
            if not plan:
                continue
            # model card: retry a runaway once (stochastic; 2nd attempt usually ends)
            tokens = sum(len(engine.sp.encode(p.replace("1", ""), out_type=int))
                         for p, _ in plan)
            cap = tokens / engine.tps_est + engine.gen_pad + 1
            for attempt in range(2):
                audio = engine.synthesize(plan, voice_path(req.voice), pace=pace)
                if len(audio) / SR <= cap + 2.0:  # multi-chunk texts run longer
                    break
            phonemes_all.append(" ".join(p.replace("1", "") for p, _ in plan))
            chunks.append(audio)
            chunks.append(np.zeros(int(PAUSE_S / pace * SR), dtype=audio.dtype))

    if not chunks:
        raise HTTPException(400, "متنی برای ساخت صدا پیدا نشد")
    audio = np.concatenate(chunks[:-1])  # drop trailing pause
    duration = len(audio) / SR

    buf = io.BytesIO()
    sf.write(buf, audio, SR, format="WAV")
    audio_id = uuid.uuid4().hex[:12]
    with _store_lock:
        _audio_store[audio_id] = {
            "wav": buf.getvalue(),
            "text": text,
            "voice": req.voice,
            "duration": duration,
            "phonemes": " ".join(phonemes_all),
        }
    return {
        "id": audio_id,
        "phonemes": " ".join(phonemes_all),
        "duration": round(duration, 2),
        "pace": pace,
        "mode": req.mode,
        "sentences": len(phonemes_all),
        "elapsed": None,
    }


@app.get("/api/audio/{audio_id}")
def audio(audio_id: str):
    with _store_lock:
        item = _audio_store.get(audio_id)
    if item is None:
        raise HTTPException(404, "not found")
    return Response(content=item["wav"], media_type="audio/wav")


@app.post("/api/voice/upload")
async def upload_voice(file: UploadFile = File(...)):
    import scipy.signal as sig

    _ensure_sr()  # a voice upload must not need the engine to know the rate

    data = await file.read()
    try:
        wav, sr = sf.read(io.BytesIO(data))
    except Exception:
        raise HTTPException(400, "فایل صوتی خوانده نشد — WAV پیشنهاد می‌شود")
    if wav.ndim > 1:
        wav = wav.mean(axis=1)
    wav = wav.astype(np.float32)
    if sr != SR:
        g = np.gcd(int(sr), SR)
        wav = sig.resample_poly(wav, SR // g, sr // g).astype(np.float32)
    if len(wav) < SR:  # < 1 s is too short to clone
        raise HTTPException(400, "صدای مرجع باید حداقل ۱ ثانیه باشد")
    wav = wav[: 5 * SR]  # model card: prompts beyond 5 s are out of distribution

    vid = f"upload:{uuid.uuid4().hex[:8]}.wav"
    try:
        UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
        sf.write(UPLOAD_DIR / vid[7:], wav, SR, format="WAV")
    except OSError as exc:
        raise HTTPException(500, f"ذخیرهٔ صدا در {UPLOAD_DIR} ممکن نشد: {exc}") from exc
    return {"id": vid, "name": vid[7:], "seconds": round(len(wav) / SR, 1)}


def configure(model_dir: Path | str | None = None, data_dir: Path | str | None = None) -> None:
    """Point the server at a model/data folder at runtime.

    The desktop shell sets PARSIGO_MODEL_DIR before importing this module (the
    engine reads it while being imported), so this only needs to move the
    writable side and refresh the cached sample rate. Safe to call twice.
    """
    global DATA_DIR, UPLOAD_DIR, _sr_loaded
    if data_dir:
        DATA_DIR = Path(data_dir)
        UPLOAD_DIR = DATA_DIR / "uploads" / "voices"
        UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    if model_dir:
        # too late for the engine modules, but keeps /api/health honest
        globals()["MODEL_DIR"] = Path(model_dir)
        _sr_loaded = False


def run(host: str = "127.0.0.1", port: int = 8000, preload: bool = True) -> None:
    """Blocking server, used by `python scripts/server.py --server-only`."""
    if preload and model_ready():
        print("loading engine (first request may take a moment)...")
        try:
            get_engine()
        except Exception as exc:  # noqa: BLE001
            print(f"engine failed to load: {exc}")
    print(f"demo:  http://{host}:{port}")
    uvicorn.run(app, host=host, port=port, log_level="warning")


if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser(description="پارسی‌گو — demo web server")
    # defaults keep the demo loopback-only; 0.0.0.0 exposes an
    # unauthenticated demo (disk-writing upload included) — opt in
    ap.add_argument("--host", default=os.environ.get("PARSIGO_HOST", "127.0.0.1"))
    ap.add_argument("--port", type=int, default=int(os.environ.get("PARSIGO_PORT", "8000")))
    ap.add_argument("--no-preload", action="store_true", help="load the engine on first request")
    cli = ap.parse_args()

    if not model_ready():
        print("مدل صوتی نصب نشده است — فایل‌های غایب:")
        for m in missing_model_files():
            print(f"  - {m}")
        print("راهنما: docs/WINDOWS.md یا صفحهٔ /setup در برنامهٔ دسکتاپ")
    run(cli.host, cli.port, preload=not cli.no_preload)
