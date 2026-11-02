# Voiceover script — KAMAND VOX (collage reel)

Narrator: professional Iranian female voice. **Full tashkil is kept here and in
the TTS input** so pronunciation is correct; the on-screen word cutouts are
plain Persian with no unnecessary diacritics.

Requested engine: `nimaone/persian_tts` (vendored in
`third_party/persian_tts/`), female reference voice
`voices/female_narration.wav`. See `generate-vo-persian-tts.py` and
`tts-attempt.log` for the actual run attempt in this sandbox.

| # | Display text (word cutouts) | TTS input (diacritized) |
| --- | --- | --- |
| 1 | ابروها، قبل از هر آرایشی، اولین چیزی هستن که دیده میشن. | «اَبْروها، قَبْل از هَر آرایشی، اَوَّلین چیزی هَستَن که دیده میشَن.» |
| 2 | اما خیلی از ژلها، یه لایه سفید روشون میذارن. | «اَمّا خیلی از ژِلها، یِه لایِهٔ سَفید روشون میذارَن.» |
| 3 | کمند، یه ژل لیفت ابروی کاملاً گیاهیه. | «کَمَنْد، یِه ژِلِ لیفْتِ اَبْرویِ کامِلاً گِیاهیه.» |
| 4 | بدون سفیدک. | «بدون سفیدک» (تلفظ: *Bedoon sefidak*، بدون «ـِ» اضافه) |
| 5 | بدون ریزش. | «بدون ریزش» (تلفظ: *Bedoon rizesh*) |
| 6 | فقط کافیه ابروهات رو تمیز کنی، | «فَقَط کافیه اَبْروهات رو تَمیز کُنی،» |
| 7 | برس بزنی، رو به بالا و بیرون. | «بُرِس بَزَنی، رو بِه بالا و بیرون.» |
| 8 | تارها، یکی یکی، سر جاشون قرار میگیرن. | «تارها، یِکی یِکی، سَرِ جاشون قَرار میگیرَن.» |
| 9 | استفاده آسان، نتیجه جذاب. | «اِستِفادهٔ آسان، نَتیجِهٔ جَذّاب.» |
| 10 | کمند؛ زیبایی طبیعی، هر روز. | «کَمَنْد؛ زِیباییِ طَبیعی، هَر روز.» |

> **بازضبط نهایی به درخواست کارفرما:** تلفظ «بدون سفیدک» دقیقاً به صورت
> *Bedoon sefidak* (بدون کسرهی اضافه پس از «بدون») خواسته شد، بنابراین متن
> خواندهشده **بدون اعراب** و بدون «ـِ» است: «بدون سفیدک». همراهش «بدون ریزش»
> نیز به همان شیوه بازضبط شد. `mix.wav`، `words.json` و `timeline.js` دوباره
> ساخته و هر دو MP4 بازرندر شدند. اسکریپت گوینده و گرافیک فیلم نیز در همین
> مرحله بازطراحی شد.

## Text pipeline (genuine use of the Persian_tts code)

`build-timeline.py` imports `split_phrases`, `_letter_words`, `SENTENCE_GAP`
and `_PHRASE_GAP` from the vendored `scripts/tts_onnx.py` to segment each
sentence into phrases and words. Word timings are then estimated from the
rendered clip duration plus ffmpeg `silencedetect` pauses, weighted by word
length and punctuation — so the paper word cutouts pop in **word by word in
sync with the speaker** while the camera scrolls continuously.

Rebuild:

```bash
.venv/bin/python motion/kamand-vox/audio/generate-vo-persian-tts.py   # primary
.venv/bin/python motion/kamand-vox/audio/make-audio.py                 # mix
.venv/bin/python motion/kamand-vox/audio/build-timeline.py             # words.js
```
