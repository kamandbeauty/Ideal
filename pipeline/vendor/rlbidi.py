# -*- coding: utf-8 -*-
"""
rlbidi — شیم کوچک برای ReportLab (MIT-ish، مخصوص همین پروژه)
=============================================================

ReportLab 5 فقط وقتی پشتیبانی راست‌به‌چپ را فعال می‌کند که ماژول `rlbidi`
در دسترس باشد. ReportLab روی PyPI منتشر نشده است؛ این فایل، با استفاده از
`python-bidi` همان تابع `log2vis` را با همان قرارداد پیاده می‌کند:

    log2vis(text, base_direction='RTL' | 'LTR', clean=True,
            positions_V_to_L=None) -> str

  • خروجی: رشتهٔ بصری (کاراکترها به ترتیبی که باید از چپ به راست رسم شوند)
  • اگر positions_V_to_L یک فهرست باشد، پر می‌شود به‌طوری که
    positions_V_to_L[i_visual] = i_logical
  • clean: حذف نویسه‌های کنترلی bidi (پایان‌های خط/جداسازها و جهت‌نماها)

نکته: ایندکس‌ها روی رشتهٔ تمیزشده محاسبه می‌شوند (اول clean، بعد نگاشت).
"""

import re

from bidi import algorithm

# نویسه‌های کنترلی که در نسخهٔ clean حذف می‌شوند (جهت‌نماها و پایان‌های خط/پاراگراف)
_CONTROLS = re.compile(
    '[\u200e\u200f\u202a-\u202e\u2066-\u2069\u2028\u2029\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'
)


def _visual_with_map(text, base_dir):
    storage = algorithm.get_empty_storage()
    base_level = algorithm.PARAGRAPH_LEVELS[base_dir]
    storage["base_level"] = base_level
    storage["base_dir"] = ("L", "R")[base_level]

    algorithm.get_embedding_levels(text, storage, False, False)
    algorithm.explicit_embed_and_overrides(storage, False)
    algorithm.resolve_weak_types(storage, False)
    algorithm.resolve_neutral_types(storage, False)
    algorithm.resolve_implicit_levels(storage, False)

    # پیش از مرتب‌سازی نهایی، ایندکس منطقی هر نویسه را ثبت می‌کنیم
    for i, ch in enumerate(storage["chars"]):
        ch["_idx"] = i

    algorithm.reorder_resolved_levels(storage, False)
    algorithm.apply_mirroring(storage, False)

    chars = storage["chars"]
    display = "".join(c["ch"] for c in chars)
    v2l = [c["_idx"] for c in chars]
    return display, v2l


def log2vis(text, base_direction=None, clean=True, positions_V_to_L=None):
    # 'RTL'/'LTR' -> 'R'/'L'
    _bd = {"RTL": "R", "LTR": "L", "R": "R", "L": "L"}
    if base_direction:
        base_direction = _bd.get(str(base_direction).upper())
        if base_direction is None:
            raise ValueError("base_direction must be 'RTL'/'LTR'")
    else:
        base_direction = "R" if algorithm.get_base_level(text, False) else "L"

    if clean:
        text = _CONTROLS.sub("", text)

    display, v2l = _visual_with_map(text, base_direction)

    if positions_V_to_L is not None:
        positions_V_to_L[:] = v2l

    return display
