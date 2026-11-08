#!/usr/bin/env python3
"""
پلیت‌ها را برای دوربینِ متحرک و قابِ افقیِ ۱۶:۹ آماده می‌کند.

منبعِ تصاویر ۱۳۷۶×۷۶۸ است؛ خروجی ۲۵۶۰×۱۴۴۰ (۱٫۸۶ برابر) تا زومِ دوربین
تا ~۱٫۷ برابر بدونِ نرمیِ محسوس کار کند. همان خطِ لرزش‌گیری و «لعاب»ِ
فیلم‌های قبلی، ولی روشن‌تر و گرم‌تر (کلاسِ درس، نه فیلمِ جنایی).

    python3 tools/upscale-plates.py            # همه
    python3 tools/upscale-plates.py a01 a02    # فقط این‌ها
"""
import sys, glob, os
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance, ImageChops

SRC = 'assets/plates'
OUT = 'assets/plates/hd'
W, H = 2560, 1440          # ۱٫۳۳× کادرِ ۱۹۲۰×۱۰۸۰، ۱۶:۹ کامل


def cover(im, w=W, h=H):
    s = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x, y = (im.width - w) // 2, (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


def clarity(im, radius=18, percent=45):
    """کنتراستِ موضعی: جزئیاتِ متوسط را بدون هالهٔ اضافه بیرون می‌کشد."""
    blur = im.filter(ImageFilter.GaussianBlur(radius))
    return ImageChops.blend(im, ImageChops.subtract(im, blur, 1.0), percent / 100.0)


def grade(im):
    """گریدِ نهایی: سایه‌های سرد، نورِ گرم، و یک برقِ موربِ ملایم."""
    a = np.asarray(im).astype(np.float32) / 255.0
    luma = (0.2126 * a[:, :, 0] + 0.7152 * a[:, :, 1] + 0.0722 * a[:, :, 2])
    hi = np.clip(luma / 0.62, 0, 1)[:, :, None] ** 1.6
    lo = np.clip((0.52 - luma) / 0.52, 0, 1)[:, :, None] ** 1.5

    warm = np.array([1.04, 0.98, 0.88], np.float32)      # طلاییِ ملایم
    cool = np.array([0.95, 0.99, 1.04], np.float32)      # آبیِ سرد در سایه‌ها
    a = a * (warm * hi * 0.30 + cool * lo * 0.14 + (1 - 0.30 * hi - 0.14 * lo))

    # برقِ مورب (لعاب): نوارِ نرم از بالا-راست به پایین-چپ
    h, w, _ = a.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    band = np.exp(-(((xx / w) * 0.8 + (yy / h) * 0.6 - 0.62) ** 2) / 0.055)
    a = a + (band[:, :, None] * 0.040) * (1 - a * 0.35)

    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


def main(names):
    os.makedirs(OUT, exist_ok=True)
    files = ([f'{SRC}/{n}.jpg' for n in names] if names
             else sorted(glob.glob(f'{SRC}/*.jpg')))
    for f in files:
        if not os.path.exists(f):
            print('missing', f)
            continue
        im = Image.open(f).convert('RGB')

        mid = im.resize((im.width * 3 // 2, im.height * 3 // 2), Image.LANCZOS)
        big = cover(mid)

        big = big.filter(ImageFilter.UnsharpMask(radius=2.0, percent=70, threshold=3))
        big = clarity(big, radius=24, percent=15)
        big = big.filter(ImageFilter.UnsharpMask(radius=0.9, percent=28, threshold=2))
        big = ImageEnhance.Color(big).enhance(1.10)
        big = ImageEnhance.Contrast(big).enhance(1.05)
        big = ImageEnhance.Brightness(big).enhance(1.02)
        big = grade(big)

        out = os.path.join(OUT, os.path.basename(f))
        big.save(out, 'JPEG', quality=90, optimize=True, progressive=True, subsampling=0)
        print(f'{os.path.basename(f):10s} {im.size} → {big.size}  {os.path.getsize(out)//1024} KB')


if __name__ == '__main__':
    main(sys.argv[1:])
