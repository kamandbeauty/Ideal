#!/usr/bin/env python3
"""
پلیت‌ها را برای دوربینِ پرتحرک آماده می‌کند.

منبعِ تصاویر ۷۶۸×۱۳۷۶ است؛ برای اینکه دوربین بتواند تا ~۲ برابر زوم کند و
تصویر نرم نشود، هر پلیت با Lanczos در دو مرحله بزرگ می‌شود، با unsharp mask
خطوطش تیز می‌شود و کمی «کلاریتی» می‌گیرد. خروجی: assets/plates/hd/*.jpg
(۲۶۰۰×۴۶۵۸ — ۲٫۴ برابرِ کادرِ ۱۰۸۰×۱۹۲۰).

    python3 tools/upscale-plates.py            # همه
    python3 tools/upscale-plates.py n02 s07    # فقط این‌ها
"""
import sys, glob, os
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance

SRC = 'assets/plates'
OUT = 'assets/plates/hd'
W, H = 1600, 2845          # ~۱٫۵× کادرِ ۱۰۸۰×۱۹۲۰، ۹:۱۶ کامل


def cover(im, w=W, h=H):
    s = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x, y = (im.width - w) // 2, (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


def clarity(im, radius=18, percent=45):
    """کنتراستِ موضعی: جزئیاتِ متوسط را بدون هالهٔ اضافه بیرون می‌کشد."""
    blur = im.filter(ImageFilter.GaussianBlur(radius))
    from PIL import ImageChops
    return ImageChops.blend(im, ImageChops.subtract(im, blur, 1.0), percent / 100.0)


def grade(im):
    """رنگ و لعابِ نهایی را روی خودِ تصویر می‌پزد تا لایه‌های بلندِ CSS کم شود.

    - سایه‌ها سرد و کمی آبی، نیم‌سایه‌ها گرم: عمقِ رنگی
    - یک برقِ مورب روی سطح: حسِ «لعاب»
    """
    a = np.asarray(im).astype(np.float32) / 255.0
    luma = (0.2126 * a[:, :, 0] + 0.7152 * a[:, :, 1] + 0.0722 * a[:, :, 2])
    hi = np.clip(luma / 0.62, 0, 1)[:, :, None] ** 1.6
    lo = np.clip((0.52 - luma) / 0.52, 0, 1)[:, :, None] ** 1.5

    warm = np.array([1.00, 0.94, 0.84], np.float32)      # طلایی
    cool = np.array([0.93, 0.98, 1.06], np.float32)      # آبیِ سرد
    a = a * (warm * hi * 0.42 + cool * lo * 0.22 + (1 - 0.42 * hi - 0.22 * lo))

    # برقِ مورب (لعاب): یک نوارِ نرم از بالا-راست به پایین-چپ
    h, w, _ = a.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    band = np.exp(-(((xx / w) * 0.8 + (yy / h) * 0.6 - 0.62) ** 2) / 0.055)
    a = a + (band[:, :, None] * 0.055) * (1 - a * 0.35)

    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


def main(names):
    os.makedirs(OUT, exist_ok=True)
    files = ([f'{SRC}/{n}.jpg' for n in names] if names
             else sorted(glob.glob(f'{SRC}/[ns]*.jpg')))
    for f in files:
        if not os.path.exists(f):
            print('missing', f)
            continue
        im = Image.open(f).convert('RGB')

        # دو مرحله بزرگ‌نمایی: هاله‌ها و پله‌های لبه کمتر می‌شود
        mid = im.resize((im.width * 3 // 2, im.height * 3 // 2), Image.LANCZOS)
        big = cover(mid)

        big = big.filter(ImageFilter.UnsharpMask(radius=2.0, percent=78, threshold=3))
        big = clarity(big, radius=24, percent=18)
        big = big.filter(ImageFilter.UnsharpMask(radius=0.9, percent=32, threshold=2))
        big = ImageEnhance.Color(big).enhance(1.14)
        big = ImageEnhance.Contrast(big).enhance(1.06)
        big = grade(big)

        out = os.path.join(OUT, os.path.basename(f))
        big.save(out, 'JPEG', quality=90, optimize=True, progressive=True, subsampling=0)
        print(f'{os.path.basename(f):10s} {im.size} → {big.size}  {os.path.getsize(out)//1024} KB')


if __name__ == '__main__':
    main(sys.argv[1:])
