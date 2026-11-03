#!/usr/bin/env python3
"""
پاک‌کردن نوشته‌های نامفهومِ تولیدشده با هوش مصنوعی از روی تابلوهای پلیت.

مدل تصویر روی تابلوهای چوبی، حروفِ بی‌معنی می‌سازد؛ در زومِ دوربین خوانده
می‌شوند و فیلم را خراب می‌کنند. این اسکریپت داخلِ هر تابلو را با رنگ و
بافتِ خودِ چوب پر می‌کند و قاب سیاه را دست‌نخورده می‌گذارد.

    python3 tools/clean-signs.py
"""
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PLATE = 'assets/plates/n05.jpg'

# چندضلعیِ داخلِ هر تابلو در مختصات پلیت (۱۳۰۰×۲۳۲۹)
SIGNS = [
    [(93, 637), (197, 634), (198, 740), (94, 743)],                 # تابلوی چوبی سمت چپ
    [(807, 680), (863, 680), (863, 706), (835, 722), (807, 706)],    # سپر کوچک
]

random.seed(11)


def main():
    im = Image.open(PLATE).convert('RGB')
    a = np.asarray(im).astype(np.float32)

    for poly in SIGNS:
        xs = [p[0] for p in poly]
        ys = [p[1] for p in poly]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)

        # رنگ پایه: میانهٔ پیکسل‌های نوارِ باریکِ درونِ قاب
        pad = np.concatenate([
            a[y0 + 2:y1 - 1, x0 + 1:x0 + 4].reshape(-1, 3),
            a[y0 + 2:y1 - 1, x1 - 4:x1 - 1].reshape(-1, 3),
        ])
        base = np.median(pad, axis=0)

        # پر کردنِ مستطیل با گرادیانِ نرم + دانه‌دانه‌شدن مثل بقیهٔ تصویر
        patch = np.zeros((y1 - y0, x1 - x0, 3), np.float32)
        for yy in range(y1 - y0):
            k = 0.06 * (1 - yy / max(1, y1 - y0 - 1))     # بالا کمی روشن‌تر
            patch[yy, :, :] = base * (1 + k)
        noise = np.random.normal(0, 4.2, patch.shape[:2])[:, :, None]
        patch += noise

        mask = Image.new('L', (x1 - x0, y1 - y0), 0)
        ImageDraw.Draw(mask).polygon([(x - x0, y - y0) for x, y in poly], fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(1.2))

        region = Image.fromarray(np.clip(patch, 0, 255).astype(np.uint8))
        im.paste(region, (x0, y0), mask)

    im = im.filter(ImageFilter.UnsharpMask(radius=1.6, percent=45, threshold=3))
    im.save(PLATE, 'JPEG', quality=90, optimize=True, progressive=True)
    print('cleaned', PLATE)


if __name__ == '__main__':
    main()
