# Reference reel — `DfNkAVNNVBu` (style study)

Source: <https://www.instagram.com/reel/DfNkAVNNVBu/>
Account: `@reza.saemiii` (رضا صائمی | آموزش هوش مصنوعی), collab `@moeinrabanian`
Published: 2026-11-01 · **duration 78 s** · labelled "AI content" · sound:
«حتما برای دوستات بفرست».

## Caption

> کپشن رو بخون👇👇
> اگه میخوای با هوش مصنوعی بتونی کسب و کار راه بندازی و یه شغل دوم داشته باشی
> و فقط باهاش چت نکنی کلمه نقشه را کامنت کن تا کامل بهت یاد بدمش🚀
>
> با هوش مصنوعی فقط چت نکن؛ باهاش کسبوکار بساز.
> #هوش_مصنوعی #chatgpt #claude

## What could be observed

Instagram returns HTTP 403 to direct fetches; the CDN hosts are blocked from
this sandbox. Through a text proxy we could read the page metadata, the
caption, the comments, the embed data and **two thumbnail descriptions**:

| Frame | Description |
| --- | --- |
| First frame / cover | «A piece of paper with some Arabic (Persian) text on it» — a paper / note with Persian writing |
| User-selected thumbnail | «green gift box with 4 claude vip accounts in it on top of a white box with claude logo above and below» — a 3D green gift-box / product-box visual |

Neighbouring reels from the same account are consistently described as
«poster and text», «blueprint, poster and text», «crossword puzzle and text»,
«image of text», plus a few «selfie of one or more people». So the account's
visual language is **poster / note / big text frames + occasional AI 3D
object reveals**, cut fast in a native Instagram-reel rhythm.

## What could NOT be observed

The actual video frames, motion, colour grade, typography, transitions and
sound. `scontent-*.cdninstagram.com` is unreachable from the build sandbox,
so the MP4 could not be downloaded or frame-sampled here. A direct MP4 URL
exists in the Instagram embed data but expires quickly.

## Resolution

The client then uploaded two screenshots and chose: **a new third film**,
**paper/kinetic style**, **30 seconds**. The screenshots made the style
unambiguous: cream paper background, pale grey sweeping arc, faint grid,
barcode, small `HD · MGH.MOBIN · MOTION SERIES` watermark, big black Persian
headline with one huge orange word and soft orange glow, a white rounded card
with an icon/title/sub/divider/for-line, a 3D kraft gift box with orange satin
ribbon, and an orange pill CTA (`FREE تومان`).

Implemented as `motion/kamand-paper/` (see its `brief.md`): same layout
grammar, KAMAND branding, 6 fast beats, 720 deterministic frames, 4K + 1080p
MP4 with audio. The two earlier films remain unchanged.
