# پلیت‌های «مردی که دو هفته بعد از دفنش به خانه برگشت»

> ۱۰ پلیت اول (`a01`–`a10`) ساخته و آپ‌اسکیل شدند. ۱۰ پلیت بعدی در نوبتِ بعد.
> سقفِ تولیدِ تصویر: ۱۰ عدد در هر نوبت.

پیشوندِ مشترک: `Vertical 9:16 portrait illustration, anime watercolour style, soft painterly gouache texture, gentle film grain, muted palette of deep teal, moss green and warm amber lamplight, cinematic low-key lighting, atmospheric mist, full-bleed composition, no text, no letters, no numbers, no logos, no watermark, no border, no frame.`

| پلیت | صحنه | پرامپت |
| --- | --- | --- |
| `a11` | قبر در گرگ‌ومیش (خط ۱۲–۱۳) | A single grave in a village burial ground at dusk: a mound of earth with wilted flowers and burnt-down incense sticks, a plain wooden marker post, wet grass, a leaning rain tree, mist between the trees, quiet dread. |
| `a12` | قابِ برگردانده (خط ۱۰) | Close still life on a wooden shelf inside a Thai village house: a single candle burned low, a small brass bowl of jasmine garlands, a folded white cloth and a plain wooden picture frame turned face-down, dust in the air, warm light falling off into darkness. |
| `a13` | دو هفته (خط ۱۱–۱۲) | A night view from the veranda of the stilt house: empty wooden steps, a single lamp, sixteen small tally marks scratched into a bamboo post (no letters, only simple notches), mist and fireflies beyond the railing. |
| `a14` | بازرسی و دفتر (خط ۱۵) | Two officials in plain khaki uniforms sitting at a wooden table in lamplight with an open blank ledger and a fountain pen, a village headman standing beside them, tired faces, papers with no readable marks, warm lamp against deep shadow. |
| `a15` | جسدِ ناشناس در معبد (خط ۱۵) | A Buddhist temple hall at night: a still form wrapped in white cloth resting on a low wooden platform, monks in saffron robes seated beside it chanting, candles and incense, folded hands, abstract and dignified, faces turned away. |
| `a16` | کندنِ قبر در شب (خط ۱۷–۱۸) | Two workers with a lantern digging at a grave mound at night, shovels and a rope, wet clay soil, long shadows under the rain tree, mist, cold green-teal night with a single warm light source. |
| `a17` | اشتباهِ هویت (خط ۱۹–۲۰) | Abstract close composition: a white cloth bundle on a bamboo mat lit by a lantern, a folded paper resting on it with no readable marks, jasmine flowers scattered, deep shadows all around. |
| `a18` | شبِ خانه (خط ۲۰) | The family sitting together on the veranda at night, the returned man among them staring out at the dark, a single lamp, insect haze, fireflies in the grass, warm light fading into teal night. |
| `a19` | چهرهٔ مرد (خط ۲۱) | Close portrait of the returned man's face, half lit by lamp, half in shadow, hollow tired eyes, weathered skin, unreadable expression, shallow painterly background of the wooden house. |
| `a20` | گورستان در مه (خط ۲۱–۲۲) | Wide night view of the village burial ground swallowed by mist, faint warm lights of the village far behind, bare trees, an open question left hanging, very quiet. |

بعد از تولید: `python3 tools/upscale-plates.py a11 … a20` → `node tools/word-timing.py` (با VO) → `node render.mjs --stills 8` → رندرِ کامل.

## موسیقی/صدا
`audio/build.mjs` هنوز به VOی آلکاتراز اشاره می‌کند؛ با رسیدنِ ویسِ این داستان، مسیر عوض و `node audio/build.mjs` اجرا شود.
