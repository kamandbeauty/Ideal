# اعتبار، منابع و مجوزها — Parsigo / پارسی‌گو (نسخهٔ ویندوز)

این پروژه یک **بسته‌بندی ویندوزی** از کار دیگران است. موتور صوتی، مدل‌ها و رابط کاربری
نوشتهٔ من نیستند؛ آنچه در این مخزن تازه است، پوستهٔ دسکتاپ و ابزار نصب/بسته‌بندی ویندوز
است. لطفاً مجوزها را قبل از هر استفادهٔ عمومی یا تجاری بخوانید.

## کد و خط لوله

| منبع | نقش | مجوز |
|---|---|---|
| [`nimaone/persian_tts`](https://github.com/nimaone/persian_tts) | کد اصلی: موتور ONNX (`scripts/tts_onnx.py`, `scripts/g2p_onnx.py`)، سرور دمو (`scripts/server.py`)، رابط وب (`web/`)، صداهای مرجع (`voices/`)، مستندات فنی (`docs/onnx-*.md`، `docs/upstream/`) | همان‌طور که در مخزن اصلی آمده؛ فایل مجوز جداگانه‌ای در آن مخزن نیست — برای استفادهٔ مجدد با نویسنده تماس بگیرید |
| [`mallahyari/pocket-tts`](https://github.com/mallahyari/pocket-tts) | کد و خط لولهٔ آموزش مدل پایه | طبق مخزن اصلی |
| [`kyutai-labs/pocket-tts`](https://github.com/kyutai-labs/pocket-tts) | مدل پایهٔ TTS (معماری) | طبق مخزن اصلی |

## مدل‌ها و داده‌ها

| منبع | نقش | مجوز |
|---|---|---|
| [`mehdi-hf/pocket-tts-farsi-v2`](https://huggingface.co/mehdi-hf/pocket-tts-farsi-v2) | مدل TTS فارسی (وزن‌ها، توکنایزر، `normalize_fa.py`) | **CC-BY-NC-4.0** — فقط استفادهٔ غیرتجاری، با ذکر منبع |
| [`mehdi-hf/Homo-GE2PE-Persian-HF`](https://huggingface.co/mehdi-hf/Homo-GE2PE-Persian-HF) | فونم‌ساز فارسی→فونم (ONNX، بازبسته‌بندی‌شده) | MIT © 2025 Elnaz Rahmati (بر پایهٔ `MahtaFetrat/Homo-GE2PE-Persian`) |
| [`Nimaone/pocket-tts-farsi-v2-onnx`](https://huggingface.co/Nimaone/pocket-tts-farsi-v2-onnx) | پکیج ONNX یکپارچه (همان مدل، export شده) | تابع مجوز مدل اصلی — CC-BY-NC-4.0 |
| صداهای مرجع `voices/*.wav` | نمونه‌های ۵ ثانیه‌ای برای کلونینگ | همان‌طور که در مخزن اصلی آمده |

> ⚠️ **CC-BY-NC-4.0 یعنی غیرتجاری.** استفادهٔ تجاری از خروجی صدا (مثلاً در محصول، تبلیغات
> یا سرویس پولی) بدون اجازهٔ صاحبان مدل مجاز نیست. همچنین هنگام انتشار صداهای تولیدشده،
> ذکر منبع مدل لازم است.

## فونت و اجزای همراه

| مورد | مجوز |
|---|---|
| Vazirmatn (`web/fonts/`) | SIL Open Font License 1.1 — متن در `web/fonts/OFL.txt` |
| CPython (نسخهٔ قابل حمل) | PSF License 2.0 |
| onnxruntime | MIT |
| numpy, scipy | BSD-3-Clause |
| soundfile, librosa? (استفاده نشده) | BSD-3-Clause |
| sentencepiece | Apache-2.0 |
| pedalboard | GPL-3.0 (فقط برای تغییر سرعت گفتار؛ در نسخهٔ قابل حمل داخل بسته است — برای
  توزیع تجاری این وابستگی را بررسی کنید) |
| FastAPI, uvicorn, pydantic, starlette | MIT / BSD |
| pywebview | BSD-3-Clause |
| pythonnet | MIT |
| huggingface_hub | Apache-2.0 |

`windows/build_portable.py` نسخهٔ ویندوزی CPython را از
[`astral-sh/python-build-standalone`](https://github.com/astral-sh/python-build-standalone)
می‌گیرد و چرخ‌های `win_amd64` را از PyPI. متن کامل مجوز هر بستهٔ نصب‌شده در همان بسته
(`*.dist-info/LICENSE`) موجود است.

## آنچه در این مخزن افزوده شده

`desktop/`, `windows/`, بخش‌های ویندوزی `README.md` / `docs/WINDOWS.md`، نوار وضعیت و
مسیرهای مدل در `web/index.html` و `scripts/server.py` — نوشتهٔ همین تغییرات، تحت همان
شرایطی که پروژهٔ اصلی اجازه می‌دهد در اختیار شماست.
