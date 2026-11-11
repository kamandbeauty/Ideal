#!/usr/bin/env python3
"""
هم‌ترازیِ کلمه‌به‌کلمه با صدای واقعی — قفل روی هجاهای شنیده‌شده.

    python3 tools/word-timing.py

۱. whisper فقط برای «ریتم» استفاده می‌شود: زمانِ هر کلمهٔ شنیده‌شده.
   (متنِ شنیده‌شده نویزی است و هیچ‌جا استفاده نمی‌شود)
۲. کلمه‌های متنِ تمیزِ ما با یک هم‌ترازیِ ترتیبی (DP) روی کلمه‌های شنیده‌شده
   می‌نشینند؛ پس هر کلمه دقیقاً همان لحظه روشن می‌شود که گفته می‌شود.
۳. برای کلمه‌هایی که whisper ادغام/جا انداخته، زمان بین دو لنگر تقسیم می‌شود.
۴. خروجی: content/timeline.js (SENTENCES) و content/words.js (WORDS)
"""
import json
import re
import sys
from pathlib import Path

from faster_whisper import WhisperModel

PROJECT = Path(__file__).resolve().parent.parent
VO = PROJECT.parent.parent / 'Generated Audio November 11, 2026 - 1_00PM.wav'
MODEL = '/tmp/models/whisper-base'
FPS = 30
TAIL = 1.1
LEAD = 0.08          # زیرنویس کمی قبل از اولین کلمه ظاهر می‌شود
MIN_W = 0.10         # حداقلِ مدتِ روشن‌بودنِ هر کلمه

sys.path.insert(0, str(PROJECT / 'tools'))
from script_lines import lines  # noqa: E402


def norm(s: str) -> str:
    s = s.replace('ي', 'ی').replace('ك', 'ک').replace('ﻻ', 'لا')
    s = re.sub(r'[\u064B-\u0652\u0640]', '', s)          # اعراب و کشیده
    s = s.replace('\u200c', '').replace('\u200f', '')
    s = re.sub(r'[^\w\u0600-\u06FF]', '', s)
    s = s.replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا').replace('ة', 'ه')
    return s


def bigrams(s: str):
    return {s[i:i + 2] for i in range(len(s) - 1)} or {s}


def sim(a: str, b: str) -> float:
    na, nb = norm(a), norm(b)
    if not na or not nb:
        return 0.0
    if na == nb:
        return 1.0
    A, B = bigrams(na), bigrams(nb)
    dice = 2 * len(A & B) / (len(A) + len(B))
    # کلمه‌های کوتاه: تطبیقِ نویسه‌ای هم مهم است
    same = sum(1 for x, y in zip(na, nb) if x == y) / max(len(na), len(nb))
    return 0.68 * dice + 0.32 * same


# ------------------------------------------------------------------ narration --
SCRIPT = lines()
script_words = []
for si, text in enumerate(SCRIPT):
    for w in re.split(r'\s+', text.strip()):
        if w:
            script_words.append((si, w))

# ------------------------------------------------------------------- whisper ---
CACHE = Path('/tmp/alcatraz-asr-words.json')
if CACHE.exists():
    spoken = [tuple(x) for x in json.loads(CACHE.read_text())]
    print(f'ریتمِ گفتار از کش ({len(spoken)} کلمه)')
else:
    model = WhisperModel(MODEL, device='cpu', compute_type='int8')
    segments, _ = model.transcribe(
        str(VO), language='fa', beam_size=5, vad_filter=False, word_timestamps=True,
        condition_on_previous_text=False,
        initial_prompt='آلکاتراز، فرانک موریس، خلیج سان‌فرانسیسکو، زندانی، نگهبان، قایق بادی، بارونی، فرار، ژوئن ۱۹۶۲',
    )
    spoken = []
    for seg in segments:
        for w in seg.words:
            if w.end > w.start:
                spoken.append((round(float(w.start), 3), round(float(w.end), 3), w.word.strip()))
    CACHE.write_text(json.dumps(spoken, ensure_ascii=False))
if not spoken:
    sys.exit('whisper found no words')

# --------------------------------------------------------------- DP alignment --
NS, NA = len(script_words), len(spoken)
SKIP_A, SKIP_S, BASE = 0.20, 0.30, 0.34
NEG = -1e9
dp = [[NEG] * (NA + 1) for _ in range(NS + 1)]
bk = [[0] * (NA + 1) for _ in range(NS + 1)]
dp[0][0] = 0.0
for i in range(NS + 1):
    for j in range(NA + 1):
        cur = dp[i][j]
        if cur <= NEG / 2:
            continue
        if i < NS and j < NA:
            g = cur + (sim(script_words[i][1], spoken[j][2]) - BASE)
            if g > dp[i + 1][j + 1]:
                dp[i + 1][j + 1] = g
                bk[i + 1][j + 1] = 1
        if j < NA:
            g = cur - SKIP_A
            if g > dp[i][j + 1]:
                dp[i][j + 1] = g
                bk[i][j + 1] = 2
        if i < NS:
            g = cur - SKIP_S
            if g > dp[i + 1][j]:
                dp[i + 1][j] = g
                bk[i + 1][j] = 3

pairs = []
i, j = NS, NA
while i > 0 or j > 0:
    m = bk[i][j]
    if m == 1:
        pairs.append((i - 1, j - 1))
        i, j = i - 1, j - 1
    elif m == 2:
        j -= 1
    elif m == 3:
        i -= 1
    else:                                    # نباید پیش بیاید
        if i > 0:
            i -= 1
        else:
            j -= 1
pairs.reverse()
anchors = {si: (spoken[j][0], spoken[j][1], spoken[j][2], sim(script_words[si][1], spoken[j][2]))
           for si, j in pairs}
matched = len(anchors)
print(f'{matched}/{NS} کلمه روی صدای واقعی قفل شد (whisper: {NA} کلمه)')

# --------------------------------------------------- fill the gaps (interpolate) --
times = [None] * NS
for si, (a, b, _w, _s) in anchors.items():
    times[si] = [a, b]

order = sorted(anchors)
for k in range(len(order) - 1):
    i0, i1 = order[k], order[k + 1]
    if i1 - i0 <= 1:
        continue
    lo, hi = anchors[i0][1], anchors[i1][0]
    span = max(0.02, hi - lo)
    weights = [max(1, len(script_words[i][1])) for i in range(i0 + 1, i1)]
    tot = sum(weights)
    acc = 0.0
    for n, i in enumerate(range(i0 + 1, i1)):
        a = lo + span * acc / tot
        acc += weights[n]
        b = lo + span * acc / tot
        times[i] = [a, b]

# کلمه‌های قبل از اولین لنگر و بعد از آخرین لنگر
if order:
    first = order[0]
    if first > 0:
        start = max(0.0, anchors[first][0] - 0.14 * first)
        step = (anchors[first][0] - start) / max(1, first)
        for i in range(first):
            times[i] = [start + step * i, start + step * (i + 1)]
    last = order[-1]
    if last < NS - 1:
        step = 0.20
        for n, i in enumerate(range(last + 1, NS)):
            times[i] = [anchors[last][1] + step * n, anchors[last][1] + step * (n + 1)]

# یکنواخت‌سازی و حداقلِ مدت
prev_end = 0.0
for i in range(NS):
    a, b = times[i]
    a = max(a, prev_end)
    b = max(b, a + MIN_W)
    times[i] = [a, b]
    prev_end = b

# کلمه‌های همسایه: مرزِ مشترک — نه شکافِ خالی، نه هم‌پوشانی
# (کلمهٔ روشن باید تا شروعِ کلمهٔ بعد روشن بماند تا چشم «پرش» نبیند)
for i in range(NS - 1):
    if script_words[i][0] != script_words[i + 1][0]:
        continue
    if times[i][1] > times[i + 1][0]:
        mid = (times[i][0] + times[i + 1][1]) / 2
        times[i][1] = min(times[i][1], max(times[i][0] + MIN_W, mid))
        times[i + 1][0] = max(times[i + 1][0], times[i][1])
    else:
        gap = times[i + 1][0] - times[i][1]
        if gap < 0.55:
            times[i][1] = times[i + 1][0]
        elif gap < 1.30:
            # شکافِ وسطِ جمله تقریباً همیشه خطایِ تطبیق است، نه مکثِ گوینده
            times[i][1] = round(times[i][1] + gap * 0.55, 3)
            times[i + 1][0] = times[i][1]

# --------------------------------------------------------------- sentences ----
sent_start, sent_end = [], []
for si in range(len(SCRIPT)):
    idxs = [k for k in range(NS) if script_words[k][0] == si]
    a = times[idxs[0]][0]
    b = max(times[k][1] for k in idxs)
    sent_start.append(max(0.0, a - LEAD))
    sent_end.append(b)

# نمایشِ پیوسته (موتور به شکافِ خالی نیاز ندارد): پایانِ هر جمله = شروعِ جملهٔ بعد
sent_bounds = [[sent_start[si], None] for si in range(len(SCRIPT))]
for si in range(len(SCRIPT) - 1):
    nxt = sent_bounds[si + 1][0]
    sent_bounds[si][1] = max(sent_bounds[si][0] + 0.4, nxt)

info_dur = 0.0
import subprocess
out = subprocess.run(
    [str(PROJECT.parent.parent / 'node_modules/@ffmpeg-installer/linux-x64/ffmpeg'), '-hide_banner', '-i', str(VO)],
    capture_output=True, text=True,
).stderr
m = re.search(r'Duration: (\d+):(\d+):([0-9.]+)', out)
if not m:
    sys.exit('cannot read VO duration')
vo_dur = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
duration = round(vo_dur + TAIL, 3)
frames = round(duration * FPS)
sent_bounds[-1][1] = duration

# فاصلهٔ نمایشِ هر جمله: تا کمی بعد از آخرین کلمه
hold = [round(min(sent_bounds[si][1], sent_end[si] + 0.42), 3) for si in range(len(SCRIPT))]

sentences = [{
    'i': si + 1,
    'text': SCRIPT[si],
    'start': round(sent_bounds[si][0], 3),
    'end': round(sent_bounds[si][1], 3),
    'hold': hold[si],
} for si in range(len(SCRIPT))]

# ------------------------------------------------------------------- outputs ---
rows = []
for k, (si, w) in enumerate(script_words):
    a, b = times[k]
    rows.append([si, w, round(a, 3), round(b, 3)])

(PROJECT / 'content' / 'words.js').write_text(
    '// GENERATED by tools/word-timing.py — do not edit by hand.\n'
    '// [شمارهٔ جمله، کلمه، شروع، پایان]\n'
    'export const WORDS = ' + json.dumps(rows, ensure_ascii=False) + ';\n'
)

cta = next((si for si, t in enumerate(SCRIPT) if 'لایک' in t), len(SCRIPT) - 1)
js = '// GENERATED by tools/timeline.mjs — do not edit by hand.\n'
js += f'export const FPS = {FPS};\n'
js += f'export const VO_DURATION = {vo_dur:.3f};\n'
js += f'export const DURATION = {duration};\n'
js += f'export const FRAMES = {frames};\n'
js += 'export const BLOCKS = [];\n'
js += 'export const SENTENCES = ' + json.dumps(sentences, ensure_ascii=False, indent=2) + ';\n'
js += 'export const CUES = [];\n'
js += f'export const ENDCARD = {{ start: {sentences[cta]["start"]:.3f} }};\n'
(PROJECT / 'content' / 'timeline.js').write_text(js)

print(f'فیلم {duration:.2f}s = {frames} فریم · پایان‌کارت از {sentences[cta]["start"]:.2f}s')
for s in sentences:
    print(f'  {s["i"]:2d}  {s["start"]:7.2f} → {s["end"]:7.2f}  ({s["end"] - s["start"]:5.2f}s)'
          f'  {len([r for r in rows if r[0] == s["i"] - 1])}w  {s["text"][:40]}…')
