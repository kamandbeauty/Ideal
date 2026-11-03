#!/usr/bin/env python3
"""
برش حاشیهٔ کاغذی پلیت‌ها.

برخی تصاویر با یک قاب کرم‌رنگ (کاغذ) تولید شده‌اند؛ وقتی دوربین روی تصویر
زوم می‌کند آن قاب مثل یک نوار روشن توی کادر می‌ماند. این اسکریپت قاب را
تشخیص می‌دهد، می‌بُرد و تصویر را «تمام‌کادر» به ۱۳۰۰×۲۳۲۹ می‌رساند.

    python3 tools/crop-plates.py            # همهٔ پلیت‌ها
    python3 tools/crop-plates.py n03 s07    # فقط این‌ها
"""
import sys, glob, os
import numpy as np
from PIL import Image, ImageFilter

W, H = 1300, 2329          # قالب نهایی (یک‌ونیم برابر کادر ۱۰۸۰×۱۹۲۰)
MAX_TRIM = 0.10            # حداکثر برش از هر لبه


def paper(line):
    """آیا این سطر/ستون، کاغذ یکدست و روشن است؟"""
    m = line.mean(axis=0)
    sd = line.std(axis=0).mean()
    return sd < 9 and m.min() > 185 and m[0] >= m[2] - 4


def border(a, h, w):
    def scan(get):
        n = 0
        while n < int(min(h, w) * MAX_TRIM) and paper(get(n)):
            n += 1
        return n
    return (scan(lambda i: a[i]), scan(lambda i: a[h - 1 - i]),
            scan(lambda i: a[:, i]), scan(lambda i: a[:, w - 1 - i]))


def cover(im, w=W, h=H):
    s = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x = (im.width - w) // 2
    y = (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


def main(names):
    files = [f'assets/plates/{n}.jpg' for n in names] if names else sorted(glob.glob('assets/plates/[sn]*.jpg'))
    for f in files:
        if not os.path.exists(f):
            print('missing', f)
            continue
        im = Image.open(f).convert('RGB')
        a = np.asarray(im).astype(float)
        t, b, l, r = border(a, im.height, im.width)
        if max(t, b, l, r):
            im = im.crop((l, t, im.width - r, im.height - b))
            print(f'{os.path.basename(f):12s} trimmed t{t} b{b} l{l} r{r} → {im.size}')
        else:
            print(f'{os.path.basename(f):12s} clean')
        out = cover(im)
        out = out.filter(ImageFilter.UnsharpMask(radius=2.0, percent=55, threshold=3))
        out.save(f, 'JPEG', quality=90, optimize=True, progressive=True)


if __name__ == '__main__':
    main(sys.argv[1:])
