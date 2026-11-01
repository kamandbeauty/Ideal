# Ideal — موشن گرافی با Agent Skills

پروژه برای ساخت موشن گرافی آماده شده است. اسکیل `motion-graphics` طبق استاندارد
باز [Agent Skills](https://github.com/agentskills/agentskills) نصب شده و ابزارهای
ساخت و رندر هم همراهش هستند.

> **نکته مهم درباره لینکی که فرستادید:** مخزن `agentskills/agentskills` خودِ
> «استاندارد» است، نه یک اسکیل قابل نصب. داخلش هیچ `SKILL.md` وجود ندارد و دستور
> `npx skills add agentskills/agentskills --list` خروجی «No skills found» میدهد.
> داخل آن مشخصات فرمت، مستندات و کتابخانه `skills-ref` (اعتبارسنج) قرار دارد.
> بنابراین به جای کپی کردن یک مخزن مستندات، **پشتیبانی استاندارد + نصب ابزار
> مدیریت اسکیل + ساخت اسکیل موشن گرافی منطبق بر همان استاندارد** را انجام دادیم.
> اگر منظورتان یک اسکیل آماده خاص (مثلاً از مخزن دیگری) بود، لینکش را بدهید تا
> همان را با `npx skills add` نصب کنیم.

## چی نصب شد؟

| بخش | مسیر | کارش |
| --- | --- | --- |
| اسکیل موشن گرافی | `.agents/skills/motion-graphics/` | `SKILL.md` + منابع + قالب + اسکریپت‌ها |
| لینک برای کلاینت‌ها | `.claude/skills/motion-graphics` | همان اسکیل برای Claude Code و سایر کلاینت‌ها |
| مدیریت اسکیل | `package.json` → `skills` CLI | نصب/لیست کردن اسکیل‌های دیگر |
| اعتبارسنج استاندارد | `requirements-dev.txt` → `skills-ref` | چک کردن فرانت‌متر `SKILL.md` |
| اسکریپت اعتبارسنجی | `scripts/validate-skills.sh` | `npm run skills:validate` |
| سرور پیشنمایش | `scripts/preview.mjs` | `npm run motion:preview` → پورت 8080 |
| راهنمای ایجنت | `AGENTS.md` | چه وقت کدام اسکیل فعال شود |

درون اسکیل:

```
.agents/skills/motion-graphics/
├── SKILL.md                     # فراداده + گردش کار (فعالسازی خودکار)
├── references/
│   ├── motion-design.md         # تایمینگ، ایزینگ، تایپوگرافی، ترکیب‌بندی
│   ├── stacks.md                # انتخاب بین HTML/WAAPI و Remotion و Manim و Lottie
│   └── rendering.md             # رندر فریم به فریم، ffmpeg، خروجی شفاف
├── assets/
│   └── starter.html             # صحنه 1920x1080 بدون وابستگی، با seek(frame)
└── scripts/
    ├── new-motion.mjs           # ساخت صحنه جدید
    └── render.mjs               # خروجی MP4 / WebM شفاف
```

نکته فنی کلیدی: صحنه‌ها **قطعی (deterministic)** هستند؛ یعنی هر فریم فقط از
شماره فریم محاسبه میشود (`window.__MOTION__.seek(frame)`) نه از ساعت سیستم.
همین باعث میشود رندر با Chromium + ffmpeg همیشه یک خروجی بدهد.

## راهاندازی

```bash
npm install
python3 -m pip install -r requirements-dev.txt   # برای اعتبارسنجی اسکیل
npm run skills:validate                         # باید Valid skill بدهد
npm run skills:list                             # اسکیل شناسایی شده را نشان میدهد

# فقط برای خروجی گرفتن ویدیو (اختیاری):
npm i -D playwright && npx playwright install chromium
# ffmpeg هم باید روی PATH باشد: apt install ffmpeg / brew install ffmpeg
```

## ساخت اولین موشن گرافی

```bash
npm run motion:preview                          # پیشنمایش زنده روی پورت 8080
npm run motion:new -- brand-intro
# ویرایش: motion/brand-intro/index.html  و  motion/brand-intro/brief.md
# پیشنمایش تکفریم: /motion/brand-intro/index.html?frame=90
npm run motion:render -- brand-intro            # → out/brand-intro.mp4
npm run motion:render -- brand-intro --alpha    # → out/brand-intro.webm شفاف
```

سرور پیشنمایش فقط پوشههای `motion/`، `out/` و `assets/` اسکیل را سرو میکند و
بدون هیچ وابستهای روی `0.0.0.0` بالا میآید، پس داخل محیط Preview هم کار میکند.

پیشفرضها: `1920x1080`، `30 fps`، `6 ثانیه (180 فریم)`، بدون صدا. متن حتماً داخل
حاشیه امن ۱۰٪ نگه داشته میشود تا برای خروجی عمودی ۹:۱۶ هم قابل برش باشد.
برای جزئیات طراحی و تایمینگ، `SKILL.md` و `references/` را ببینید.

## نصب اسکیل‌های دیگر

```bash
npx skills add <owner>/<repo> --skill <skill-name> -a '*' -y
npx skills add <owner>/<repo> --list            # دیدن اسکیل‌های موجود در مخزن
```

بعد از اضافه شدن، `npm run skills:validate` را دوباره اجرا کنید.

## یادداشت

ویدیوها، دنباله فریم‌های PNG و `node_modules/` داخل گیت نمیآیند (`.gitignore`)؛
فقط فایل‌های قابل ویرایش و `brief.md` نگهداری میشوند.
