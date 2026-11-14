# Stickman Video Projects

ویدیوهای ساخته‌شده با اسکیل [stickman-video-director](https://github.com/kaomei/stickman-video-director) و موتورهای انیمیشن اختصاصی.

| پوشه | توضیح | خروجی |
|---|---|---|
| `stickman-demo/` | دموی آزمایشی سبک B1 (خط‌کشی مینیمال)، ۱۶ ثانیه | `output/film.mp4` |
| `stickman-rowling/` | داستان جی. کی. رولینگ — سبک B2 رنگی دست‌کشیده، عمودی 9:16، نریشن فارسی (پیش‌نمایش ۲۴ ثانیه‌ای) | `output/preview.mp4` |
| `dialogue-3d/` | دیالوگ دو کاراکتر مانکن مفصل‌دار سه‌بعدی با لیپ‌سینک و ریگ FK — `render.py` | `output/dialogue.mp4` |
| `dialogue-stickman/` | همان دیالوگ با استیکمن کلاسیک دوبعدی — اسکلت رویه‌ای، IK پا، لرزش خط دستی — `render.py` | `output/dialogue.mp4` |

## اجرای رندرهای اختصاصی (dialogue-*)

```bash
pip install pillow numpy scipy arabic-reshaper python-bidi imageio-ffmpeg
python3 render.py          # فریم‌ها در /tmp
# سپس انکود با ffmpeg (دستور در تاریخچه‌ی کامیت)
```

## بازتولید پروژه‌های اسکیل (stickman-*)

```bash
git clone --depth 1 https://github.com/kaomei/stickman-video-director /tmp/svd
cd /tmp/svd/skills/directing-stickman-videos && npm install
node scripts/autopilot.mjs validate|preview|render <project.json>
```
