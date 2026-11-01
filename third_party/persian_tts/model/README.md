# Model weights — intentionally NOT in Git

`nimaone/persian_tts` needs the ~469 MB ONNX package
`Nimaone/pocket-tts-farsi-v2-onnx`, hosted on HuggingFace. The upstream repo
gitignores `model/`, and this sandbox's outbound policy allows only
github.com / npm / PyPI — `huggingface.co` is unreachable from `bash` here, so
the weights could not be fetched during this build.

On any machine with normal internet access, run **once**:

```bash
python3 -m pip install -U "huggingface_hub[cli]"
hf download Nimaone/pocket-tts-farsi-v2-onnx \
  --local-dir third_party/persian_tts/model/onnx
```

Two small host-side files also come from the upstream model repo and must sit
in `third_party/persian_tts/model/v2/` (the vendored `g2p_onnx.py` imports
`normalize_fa.py` and `tts_onnx.py` loads `tokenizer_ph.model` from there):

```bash
mkdir -p third_party/persian_tts/model/v2
B=https://huggingface.co/mehdi-hf/pocket-tts-farsi-v2/resolve/main
for f in normalize_fa.py tokenizer_ph.model; do
  curl -L -o "third_party/persian_tts/model/v2/$f" "$B/$f"
done
```

Then install the CPU runtime deps and regenerate:

```bash
python3 -m pip install -r requirements-persian-tts.txt
python3 motion/kamand-eye/audio/generate-vo-persian-tts.py
```

Everything under `model/` is gitignored (`third_party/persian_tts/model/`),
so no large binaries enter the repository.
