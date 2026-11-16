#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
IDEAL — ساخت PDF فارسی از فایل مارک‌داون.

استفاده:
    python pipeline/build.py <ورودی.md> <خروجی.pdf> [--toc]

با --toc یک فهرست مطالب با شمارهٔ صفحهٔ درست درج می‌شود. ساخت در چند دور
انجام می‌شود تا وقتی که شمارهٔ چاپ‌شده در فهرست دقیقاً با شمارهٔ واقعی
صفحه‌ها یکی شود (نقطه‌ی ثابت).
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fa_pdf


def main():
    ap = argparse.ArgumentParser(description='ساخت PDF فارسی با فونت وزیرمتن')
    ap.add_argument('input', help='فایل مارک‌داون ورودی (با @سربرگ‌ها)')
    ap.add_argument('output', help='فایل PDF خروجی')
    ap.add_argument('--toc', action='store_true', help='فهرست مطالب را درج کن')
    args = ap.parse_args()

    if not os.path.exists(args.input):
        ap.error('فایل ورودی پیدا نشد: ' + args.input)

    out_dir = os.path.dirname(os.path.abspath(args.output))
    os.makedirs(out_dir, exist_ok=True)

    if not args.toc:
        fa_pdf.build(args.input, args.output)
        print('✔ ساخته شد:', args.output)
        return

    entries = None
    for _ in range(4):
        actual = fa_pdf.build(args.input, args.output, toc_entries=entries)
        if entries is not None and actual == entries:
            break
        entries = actual

    print('✔ ساخته شد:', args.output)


if __name__ == '__main__':
    main()
