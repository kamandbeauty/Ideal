# -*- coding: utf-8 -*-
"""
موتور ساخت PDF فارسی با فونت وزیرمتن — پروژهٔ Ideal
Persian/Farsi PDF typesetting engine.

رویکرد / Approach
------------------
ReportLab 5 پشتیبانی RTL خود را روی `rlbidi` بسته است که قابل نصب نیست
(رجوع کنید به pipeline/vendor/rlbidi.py)، و کد مرتب‌سازی کلماتِ آن در این نسخه
عملاً غیرفعال است. بنابراین چیدمان پاراگراف‌ها کاملاً اینجا پیاده شده است:

  • متن به «کلمات» شکسته می‌شود (صرفاً روی فاصله‌ها؛ حروف ربط و فاصله‌مجازی
    جدا نمی‌شوند).
  • هر کلمه با HarfBuzz شکل می‌گیرد (kern/liga) و جهت آن تشخیص داده می‌شود.
  • شکست خط به‌صورت حریصانه و راست‌چین انجام می‌شود؛ سطرهای غیرآخر ترازبندی
    (justify) می‌شوند با افزایش فاصلهٔ بین کلمات.
  • هر کلمه با drawString(..., direction='rtl'|'ltr', shaping=True) رسم می‌شود
    پس ترتیب و شکل حروف همیشه درست است.

ویژگی‌ها: جلد تیرهٔ‌بنفش با نشانِ هندسی، سرصفحه/پاورقی ظریف، شمارهٔ صفحهٔ
فارسی، فهرست مطالب دو‌مرحله‌ای، عنوان‌های سلسله‌مراتبی، نقل‌قول جعبه‌ای،
فهرست‌های نقطه‌ای/شماره‌دار فارسی، جدول و بلوک کد.
"""

import os
import re
import sys

from reportlab.lib.pagesizes import A5
from reportlab.lib.units import mm
from reportlab.lib.colors import Color, HexColor, white
from reportlab.lib.enums import TA_RIGHT, TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase.pdfmetrics import registerFontFamily
from reportlab.platypus import (
    BaseDocTemplate, PageTemplate, Frame, Flowable, Spacer, PageBreak,
    Table, TableStyle, KeepTogether, HRFlowable, NextPageTemplate, Paragraph,
)
from reportlab.lib.styles import ParagraphStyle

import uharfbuzz

# --- سازگاری با ReportLab (کرش setRise در مسیر shaping) ------------------
# در مسیر shaping وقتی اولین کلاسترِ یک خط y_offset غیرصفر دارد (مثلاً همزهٔ
# بالای حرف)، setRise با فهرست خالیِ _code صدا زده می‌شود و کرش می‌کند.
# این پوشش فقط همان گارد را اضافه می‌کند و رفتار را تغییر نمی‌دهد.
from reportlab.pdfgen import textobject as _textobject

if hasattr(_textobject, 'PDFTextObject'):
    def _safe_setRise(self, rise):
        from reportlab.pdfgen.textobject import fp_str
        v = f'{fp_str(rise)} Ts'
        code = getattr(self, '_code', None)
        if code and code[-1].endswith(' Ts'):
            self._y += self._rise
            code[-1] = v
        else:
            self._rise = rise
            self._y -= rise
            self._code = code if code is not None else []
            self._code.append(v)

    _textobject.PDFTextObject.setRise = _safe_setRise

# ---------------------------------------------------------------- رنگ‌ها
INK         = HexColor('#25222B')
PAPER       = HexColor('#FCFBF7')
ACCENT      = HexColor('#6D28D9')
ACCENT_DARK = HexColor('#3B0764')
ACCENT_SOFT = HexColor('#EFE9FB')
ACCENT_LINE = HexColor('#D9D2EE')
GOLD        = HexColor('#C9A227')
GOLD_LIGHT  = HexColor('#E3C878')
MUTED       = HexColor('#6E6878')

# ---------------------------------------------------------------- فونت‌ها
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FONT_DIR = os.path.join(ROOT, 'fonts', 'vazirmatn')

FONTS = {
    'Vazirmatn':             'Vazirmatn-Regular.ttf',
    'Vazirmatn-Light':       'Vazirmatn-Light.ttf',
    'Vazirmatn-Medium':      'Vazirmatn-Medium.ttf',
    'Vazirmatn-SemiBold':    'Vazirmatn-SemiBold.ttf',
    'Vazirmatn-Bold':        'Vazirmatn-Bold.ttf',
    'Vazirmatn-ExtraBold':   'Vazirmatn-ExtraBold.ttf',
    'Vazirmatn-Black':       'Vazirmatn-Black.ttf',
}

def register_fonts():
    for name, fname in FONTS.items():
        path = os.path.join(FONT_DIR, fname)
        if not os.path.exists(path):
            raise FileNotFoundError('فونت پیدا نشد: ' + path)
        pdfmetrics.registerFont(TTFont(name, path))
    registerFontFamily('Vazirmatn', normal='Vazirmatn',
                       bold='Vazirmatn-Bold', italic='Vazirmatn-Medium',
                       boldItalic='Vazirmatn-ExtraBold')

# ---------------------------------------------------------------- کش HarfBuzz
_HB_FONTS = {}
_HB_SHAPE = {}

def _hb_font(name):
    cached = _HB_FONTS.get(name)
    if cached is None:
        with open(os.path.join(FONT_DIR, FONTS[name]), 'rb') as fh:
            blob = uharfbuzz.Blob(fh.read())
        face = uharfbuzz.Face(blob)
        _HB_FONTS[name] = (uharfbuzz.Font(face), face.upem)
        cached = _HB_FONTS[name]
    return cached

def hb_shape(word, font, size):
    """(عرض به نقطه، جهت) کلمهٔ شکل‌داده‌شده را برمی‌گرداند؛ با کش."""
    key = (word, font, size)
    hit = _HB_SHAPE.get(key)
    if hit is None:
        buf_font, upem = _hb_font(font)
        buf = uharfbuzz.Buffer()
        buf.cluster_level = uharfbuzz.BufferClusterLevel.MONOTONE_CHARACTERS
        buf.add_str(word)
        buf.guess_segment_properties()
        uharfbuzz.shape(buf_font, buf, {'kern': True, 'liga': True, 'dlig': True})
        width = sum(p.x_advance for p in buf.glyph_positions) * size / upem
        direction = 'rtl' if buf.direction == 'rtl' else 'ltr'
        _HB_SHAPE[key] = hit = (width, direction)
    return hit

# ---------------------------------------------------------------- ابزارهای متن
_PERSIAN_DIGITS = '۰۱۲۳۴۵۶۷۸۹'

def fa_digits(s):
    """تبدیل ارقام لاتین به ارقام فارسی."""
    return ''.join(_PERSIAN_DIGITS[int(ch)] if ch.isdigit() else ch for ch in str(s))

def clean_markup(text):
    """متن بدون مارک‌آپ — یونیکد منطقی (برای متادیتا/Outline/فهرست)."""
    txt = re.sub(r'\*\*(.+?)\*\*', r'\1', text, flags=re.S)
    txt = re.sub(r'\*(.+?)\*', r'\1', txt, flags=re.S)
    return txt

_INLINE = re.compile(r'(\*\*.+?\*\*|\*.+?\*)', re.S)
_WS = re.compile(r'[ \t]+')

def tokenize(text, fontmap):
    """متن + مارک‌آپ ساده → توکن‌ها: ('w', word, font) | ('br',)"""
    segments = []
    for part in _INLINE.split(text):
        if not part:
            continue
        if part.startswith('**') and part.endswith('**') and len(part) > 4:
            segments.append(('b', part[2:-2]))
        elif part.startswith('*') and part.endswith('*') and len(part) > 2:
            segments.append(('i', part[1:-1]))
        else:
            segments.append(('n', part))

    tokens = []
    for kind, seg in segments:
        font = fontmap[kind]
        for li, ln in enumerate(seg.split('\n')):
            if li:
                tokens.append(('br',))
            for piece in _WS.split(ln):
                if piece:
                    tokens.append(('w', piece, kind))
    return tokens

# ---------------------------------------------------------------- استایل‌ها
def _st(name, fontSize, leading, align, color, spaceBefore=0, spaceAfter=0,
        rightIndent=0, firstLineIndent=0, leftIndent=0,
        boldFont=None, semiFont=None):
    s = ParagraphStyle(name, fontName=fontSize and 'Vazirmatn', fontSize=fontSize,
                       leading=leading, alignment=align, textColor=color,
                       spaceBefore=spaceBefore, spaceAfter=spaceAfter,
                       rightIndent=rightIndent, firstLineIndent=firstLineIndent,
                       leftIndent=leftIndent)
    s.normalFont = 'Vazirmatn' if name not in ('H1', 'H2', 'H3', 'Quote', 'Code', 'TOC1', 'TOC2', 'TOCTitle') else {
        'H1': 'Vazirmatn-ExtraBold', 'H2': 'Vazirmatn-Bold', 'H3': 'Vazirmatn-SemiBold',
        'Quote': 'Vazirmatn-Medium', 'Code': 'Vazirmatn-Medium',
        'TOC1': 'Vazirmatn-SemiBold', 'TOC2': 'Vazirmatn', 'TOCTitle': 'Vazirmatn-ExtraBold',
    }[name]
    s.boldFont = boldFont or 'Vazirmatn-Bold'
    s.semiFont = semiFont or 'Vazirmatn-SemiBold'
    return s

def make_styles():
    styles = {}
    styles['Body'] = _st('Body', 11, 21, TA_JUSTIFY, INK, spaceAfter=7,
                         boldFont='Vazirmatn-Bold', semiFont='Vazirmatn-SemiBold')
    styles['H1'] = _st('H1', 18.5, 29, TA_RIGHT, ACCENT_DARK, spaceBefore=10, spaceAfter=6,
                       boldFont='Vazirmatn-Black', semiFont='Vazirmatn-ExtraBold')
    styles['H2'] = _st('H2', 14, 23, TA_RIGHT, ACCENT_DARK, spaceBefore=13, spaceAfter=6,
                       boldFont='Vazirmatn-ExtraBold', semiFont='Vazirmatn-Bold')
    styles['H3'] = _st('H3', 11.5, 20, TA_RIGHT, ACCENT, spaceBefore=10, spaceAfter=4,
                       boldFont='Vazirmatn-Bold', semiFont='Vazirmatn-SemiBold')
    styles['Quote'] = _st('Quote', 10.5, 19.5, TA_JUSTIFY, ACCENT_DARK,
                          boldFont='Vazirmatn-Bold', semiFont='Vazirmatn-SemiBold')
    styles['Code'] = _st('Code', 9, 15, TA_LEFT, INK,
                         boldFont='Vazirmatn-Bold', semiFont='Vazirmatn-Medium')
    styles['ListItem'] = _st('ListItem', 10.5, 19, TA_JUSTIFY, INK,
                             rightIndent=14, firstLineIndent=-14,
                             boldFont='Vazirmatn-Bold', semiFont='Vazirmatn-SemiBold')
    styles['OLItem'] = _st('OLItem', 10.5, 19, TA_JUSTIFY, INK,
                           rightIndent=16, firstLineIndent=-16,
                           boldFont='Vazirmatn-Bold', semiFont='Vazirmatn-SemiBold')
    styles['Caption'] = _st('Caption', 8.5, 14, TA_CENTER, MUTED, spaceBefore=4, spaceAfter=10)
    styles['TOCTitle'] = _st('TOCTitle', 17, 27, TA_RIGHT, ACCENT_DARK, spaceBefore=6, spaceAfter=12)
    styles['TOC1'] = _st('TOC1', 10.5, 19, TA_RIGHT, INK)
    styles['TOC2'] = _st('TOC2', 9.5, 16, TA_RIGHT, MUTED, rightIndent=16)
    return styles

# ---------------------------------------------------------------- پاراگراف فارسی
class PersianParagraph(Flowable):
    """پاراگراف RTL راست‌چین/ترازشده با شکل‌دهی HarfBuzz."""

    def __init__(self, text, style, marker=None, kind=None):
        super().__init__()
        self.text = text
        self.style = style
        self.marker = marker            # (text, font, hexcolor) یا None
        self._kind = kind               # 'h1'|'h2'|'h3' برای Outline/TOC
        s = style
        self.fontmap = {'n': s.normalFont, 'b': s.boldFont, 'i': s.semiFont}
        self._lines = None              # list of (words, natural_width)
        self._layout_width = None

    # -- چیدمان -----------------------------------------------------------
    def _layout(self, width):
        size = self.style.fontSize
        tokens = tokenize(self.text, self.fontmap)
        if self.marker:
            tokens = [('w', self.marker[0], 'marker')] + ([('s',)] if False else []) + tokens
        # توکن‌ها: ('w', word, font) | ('br',) ؛ فاصله‌ها ضمن‌ضمنی بین کلمات‌اند
        space_w = hb_shape(' ', self.fontmap['n'], size)[0]

        words = []
        for t in tokens:
            if t[0] == 'br':
                words.append({'br': True})
                continue
            kind = t[2]
            if kind == 'marker':
                font, color = self.marker[1], self.marker[2]
            else:
                font, color = self.fontmap[kind], None
            w, d = hb_shape(t[1], font, size)
            words.append({'text': t[1], 'font': font, 'w': w, 'dir': d, 'color': color})

        st = self.style
        avail = width - st.leftIndent - st.rightIndent
        right_edge = width - st.rightIndent  # شروع از راست
        # firstLineIndent منفی: خط اول به سمت بیرون (راست) می‌رود
        first_offset = -st.firstLineIndent if st.firstLineIndent < 0 else 0

        lines, cur, cur_w = [], [], 0.0
        line_width = avail + first_offset

        def flush():
            nonlocal cur, cur_w, line_width
            edge = right_edge + (first_offset if len(lines) == 0 else 0)
            lines.append((cur, cur_w, edge))
            cur, cur_w = [], 0.0
            line_width = avail

        for wd in words:
            if wd.get('br'):
                flush()
                continue
            add = wd['w'] + (space_w if cur else 0.0)
            if cur and cur_w + add > line_width:
                flush()
                cur, cur_w = [wd], wd['w']
            else:
                if cur:
                    cur_w += space_w
                cur.append(wd)
                cur_w += wd['w']
        if cur:
            flush()
        return lines, avail, space_w

    def wrap(self, availWidth, availHeight):
        if self._lines is None:
            self._lines, avail, self._space_w = self._layout(availWidth)
            self._layout_width = availWidth
        self.width = availWidth
        self.height = max(1, len(self._lines)) * self.style.leading
        return availWidth, self.height

    def _draw_line(self, canv, words, natural_w, y, avail, space_w, edge, is_last):
        st = self.style
        size = st.fontSize
        align = st.alignment
        if align == TA_JUSTIFY and is_last:
            align = TA_RIGHT
        n_gaps = max(0, len(words) - 1)
        extra = 0.0
        if align == TA_JUSTIFY and n_gaps:
            extra = max(0.0, min((avail - natural_w) / n_gaps, space_w * 0.75))
        elif align == TA_CENTER:
            edge = st.leftIndent + (avail + natural_w) / 2.0
        elif align == TA_LEFT:
            edge = st.leftIndent + natural_w
        x = edge
        for wd in words:
            x -= wd['w']
            canv.saveState()
            canv.setFillColor(wd['color'] or st.textColor)
            canv.setFont(wd['font'], size)
            canv.drawString(x, y, wd['text'], direction=wd['dir'], shaping=True)
            canv.restoreState()
            x -= space_w + extra

    def draw(self):
        st = self.style
        canv = self.canv
        leading = st.leading
        size = st.fontSize
        base_offset = (leading - size) * 0.5 + size * 0.30
        y = self.height - base_offset
        avail = self._layout_width - st.leftIndent - st.rightIndent
        for i, (words, natural_w, edge) in enumerate(self._lines):
            is_last = i == len(self._lines) - 1
            self._draw_line(canv, words, natural_w, y, avail, self._space_w, edge, is_last)
            y -= leading

    # -- شکست صفحه ----------------------------------------------------------
    @classmethod
    def _from_lines(cls, lines, style, marker, kind, space_w):
        obj = cls.__new__(cls)
        Flowable.__init__(obj)
        obj.text, obj.style, obj.marker, obj._kind = '', style, marker, kind
        obj.fontmap = {'n': style.normalFont, 'b': style.boldFont, 'i': style.semiFont}
        obj._layout_width = None
        obj._lines = lines
        obj._space_w = space_w
        return obj

    def split(self, availWidth, availHeight):
        if self._lines is None:
            self._lines, avail, self._space_w = self._layout(availWidth)
            self._layout_width = availWidth
        leading = self.style.leading
        fit = int(availHeight // leading)
        if fit >= len(self._lines):
            return [self]
        if fit <= 0:
            return []
        first = self._from_lines(self._lines[:fit], self.style, self.marker, self._kind, self._space_w)
        rest = self._from_lines(self._lines[fit:], self.style, None, self._kind, self._space_w)
        first._layout_width = rest._layout_width = availWidth
        return [first, rest]

    def getPlainText(self):
        return clean_markup(self.text)


# ---------------------------------------------------------------- خط کد
_ARABIC_RUN = re.compile(r'[\u0600-\u06FF\u0750-\u077F\u0870-\u089F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]+')

class CodeLine(Flowable):
    """یک خط کد با پشتیبانی صحیح از اجزای فارسی (هر run با جهت خودش رسم می‌شود)."""

    def __init__(self, text, style):
        super().__init__()
        self.text = text
        self.style = style
        self._runs = None
        self._total = 0.0

    def _split_runs(self):
        runs = []
        pos = 0
        for m in _ARABIC_RUN.finditer(self.text):
            if m.start() > pos:
                runs.append((self.text[pos:m.start()], 'ltr'))
            runs.append((m.group(0), 'rtl'))
            pos = m.end()
        if pos < len(self.text):
            runs.append((self.text[pos:], 'ltr'))
        return runs or [(' ', 'ltr')]

    def wrap(self, availWidth, availHeight):
        self.width = availWidth
        self.height = self.style.leading
        if self._runs is None:
            self._runs = self._split_runs()
            self._total = sum(hb_shape(t, self.style.normalFont, self.style.fontSize)[0]
                              for t, _ in self._runs)
        return availWidth, self.height

    def draw(self):
        canv = self.canv
        st = self.style
        y = (st.leading - st.fontSize) * 0.5 + st.fontSize * 0.30
        x = 0.0
        for text, direction in self._runs:
            canv.saveState()
            canv.setFillColor(st.textColor)
            canv.setFont(st.normalFont, st.fontSize)
            canv.drawString(x, y, text, direction=direction, shaping=True)
            canv.restoreState()
            x += hb_shape(text, st.normalFont, st.fontSize)[0]

# ---------------------------------------------------------------- کمک‌کننده‌ها
def _para(text, style, marker=None, kind=None):
    return PersianParagraph(text, style, marker=marker, kind=kind)

def _quote_box(text, styles):
    inner = _para(text, styles['Quote'])
    t = Table([[inner]], colWidths=[A5[0] - 32 * mm])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), ACCENT_SOFT),
        ('LINEAFTER', (0, 0), (0, -1), 2.6, GOLD),
        ('LEFTPADDING', (0, 0), (-1, -1), 12),
        ('RIGHTPADDING', (0, 0), (-1, -1), 12),
        ('TOPPADDING', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
    ]))
    return t

def _code_box(text, styles):
    lines = text.split('\n') or ['']
    paras = [CodeLine(ln if ln else ' ', styles['Code']) for ln in lines]
    inner = Table([[p] for p in paras], colWidths=[A5[0] - 32 * mm])
    inner.setStyle(TableStyle([
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
    ]))
    t = Table([[inner]], colWidths=[A5[0] - 32 * mm])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), HexColor('#F4F2EF')),
        ('BOX', (0, 0), (-1, -1), 0.6, ACCENT_LINE),
        ('LEFTPADDING', (0, 0), (-1, -1), 10),
        ('RIGHTPADDING', (0, 0), (-1, -1), 10),
        ('TOPPADDING', (0, 0), (-1, -1), 8),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ]))
    return t

def _table_flowable(lines, styles):
    rows = []
    for ln in lines.split('\n'):
        cells = [c.strip() for c in ln.strip().strip('|').split('|')]
        rows.append(cells)
    if len(rows) >= 2 and all(set(c) <= set('-: ') for c in rows[1]):
        del rows[1]
    if not rows:
        return Spacer(1, 1)
    ncols = max(len(r) for r in rows)
    rows = [r + [''] * (ncols - len(r)) for r in rows]
    data = []
    for ridx, r in enumerate(rows):
        line = []
        for c in r:
            cell_style = ParagraphStyle(
                'cell', fontName='Vazirmatn-Bold' if ridx == 0 else 'Vazirmatn',
                fontSize=8.6, leading=15, alignment=TA_CENTER if ridx == 0 else TA_RIGHT,
                textColor=ACCENT_DARK if ridx == 0 else INK)
            cell_style.normalFont = cell_style.fontName
            cell_style.boldFont = 'Vazirmatn-ExtraBold' if ridx == 0 else 'Vazirmatn-Bold'
            cell_style.semiFont = cell_style.normalFont
            line.append(_para(c, cell_style))
        data.append(line)
    frame_width = A5[0] - 32 * mm
    t = Table(data, colWidths=[frame_width / ncols] * ncols, repeatRows=1)
    style = [
        ('BACKGROUND', (0, 0), (-1, 0), ACCENT_SOFT),
        ('LINEBELOW', (0, 0), (-1, 0), 1.1, ACCENT),
        ('GRID', (0, 0), (-1, -1), 0.35, ACCENT_LINE),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (0, 0), (-1, -1), 7),
        ('RIGHTPADDING', (0, 0), (-1, -1), 7),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]
    for ridx in range(1, len(rows)):
        if ridx % 2 == 0:
            style.append(('BACKGROUND', (0, ridx), (-1, ridx), HexColor('#FBFAFE')))
    t.setStyle(TableStyle(style))
    return t

def _list_flowables(items_text, styles, ordered):
    flow = []
    for n, item in enumerate(items_text.split('\n'), 1):
        if ordered:
            marker = (fa_digits(n) + '.', 'Vazirmatn-Bold', '#6D28D9')
            styles_key = 'OLItem'
        else:
            marker = ('•', 'Vazirmatn-Bold', '#C9A227')
            styles_key = 'ListItem'
        flow.append(_para(item, styles[styles_key], marker=marker))
    return flow

# ---------------------------------------------------------------- جلد و صفحات
def _lerp(c1, c2, t):
    return Color(c1.red + (c2.red - c1.red) * t,
                 c1.green + (c2.green - c1.green) * t,
                 c1.blue + (c2.blue - c1.blue) * t)

def draw_cover(canv, doc, meta):
    W, H = A5
    top, bottom = HexColor('#170B2E'), HexColor('#241145')
    bands = 160
    for i in range(bands):
        t = i / (bands - 1)
        canv.setFillColor(_lerp(top, bottom, t))
        canv.rect(0, H - (i + 1) * (H / bands), W, H / bands + 1, fill=1, stroke=0)

    canv.setTitle(plain_fa(meta.get('title', 'Ideal')))
    canv.setAuthor(plain_fa(meta.get('translator', 'ترجمهٔ فارسی')))
    canv.setSubject('نسخهٔ فارسی')
    canv.setCreator('Ideal — Persian Edition')

    cx = W / 2

    # برچسب بالای جلد
    canv.saveState()
    canv.setFillColor(GOLD_LIGHT)
    canv.setFont('Vazirmatn-SemiBold', 10)
    canv.drawCentredString(cx, H - 30 * mm, 'ترجمهٔ فارسی', direction='rtl', shaping=True)
    canv.restoreState()

    # نشان هندسی: دایره‌ها و ستارهٔ هشت‌پر
    ey = H - 62 * mm
    canv.saveState()
    canv.setLineWidth(1.1); canv.setStrokeColor(GOLD)
    canv.circle(cx, ey, 30 * mm / 2 + 24, stroke=1, fill=0)
    canv.setLineWidth(0.5)
    canv.circle(cx, ey, 30 * mm / 2 + 14, stroke=1, fill=0)
    canv.setLineWidth(1.6)
    for rot in (0, 45):
        canv.saveState()
        canv.translate(cx, ey); canv.rotate(rot)
        s = 21 * mm / 2
        canv.rect(-s, -s, 2 * s, 2 * s, stroke=1, fill=0)
        canv.restoreState()
    canv.setFillColor(HexColor('#2B1445'))
    canv.setLineWidth(1.2)
    canv.circle(cx, ey, 13, stroke=1, fill=1)
    canv.setFillColor(GOLD_LIGHT)
    canv.circle(cx, ey, 2.6, stroke=0, fill=1)
    canv.restoreState()

    # عنوان
    title_lines = (meta.get('title') or 'بدون عنوان').split('\\n')
    y = H - 100 * mm
    for i, line in enumerate(title_lines):
        size = 27 if i == 0 else 22
        canv.setFillColor(HexColor('#F5F1FD'))
        canv.setFont('Vazirmatn-Black', size)
        canv.drawCentredString(cx, y, line, direction='rtl', shaping=True)
        y -= (size + 8)

    # زیرعنوان
    if meta.get('subtitle'):
        canv.setFont('Vazirmatn-Light', 11)
        canv.setFillColor(GOLD_LIGHT)
        canv.drawCentredString(cx, y - 2, meta['subtitle'], direction='rtl', shaping=True)
        y -= 18

    # خط طلایی با الماس وسط
    y -= 6
    canv.setStrokeColor(GOLD); canv.setLineWidth(1.3)
    canv.line(cx - 42, y, cx - 5, y); canv.line(cx + 5, y, cx + 42, y)
    canv.saveState(); canv.translate(cx, y); canv.rotate(45)
    canv.setFillColor(GOLD); canv.rect(-3.1, -3.1, 6.2, 6.2, stroke=0, fill=1)
    canv.restoreState()

    # نویسنده / مترجم
    y -= 14 * mm
    for key, label in (('author', 'نویسندهٔ نسخهٔ اصلی'),
                       ('editor', 'گردآوری'),
                       ('translator', 'ترجمه')):
        if meta.get(key):
            canv.setFont('Vazirmatn-SemiBold', 8)
            canv.setFillColor(HexColor('#A99CD0'))
            canv.drawCentredString(cx, y, label, direction='rtl', shaping=True)
            canv.setFont('Vazirmatn', 10.5)
            canv.setFillColor(HexColor('#EDE9F8'))
            canv.drawCentredString(cx, y - 11, meta[key], direction='rtl', shaping=True)
            y -= 22

    # پانویس جلد
    canv.setStrokeColor(HexColor('#3A2450')); canv.setLineWidth(0.7)
    canv.line(40, 54, W - 40, 54)
    canv.setFillColor(GOLD_LIGHT)
    canv.setFont('Vazirmatn-Medium', 8.5)
    canv.drawCentredString(cx, 42, meta.get('edition', 'ویراستِ ویژهٔ فارسی'), direction='rtl', shaping=True)
    canv.setFillColor(HexColor('#8F81B8'))
    canv.setFont('Vazirmatn-SemiBold', 6.8)
    canv.drawCentredString(cx, 29, meta.get('note', 'نسخهٔ فارسی'), direction='rtl', shaping=True)

def make_content_furniture(meta):
    short_title = meta.get('shorttitle') or meta.get('title', 'Ideal')
    short_title = short_title.split('\\n')[0]

    def on_page(canv, doc):
        W, H = A5
        canv.saveState()
        # سرصفحه
        canv.setFont('Vazirmatn-SemiBold', 7.3)
        canv.setFillColor(MUTED)
        canv.drawRightString(W - 16 * mm, H - 10 * mm, short_title, direction='rtl', shaping=True)
        canv.drawString(16 * mm, H - 10 * mm, 'ترجمهٔ فارسی', direction='rtl', shaping=True)
        canv.setStrokeColor(GOLD); canv.setLineWidth(0.7)
        canv.line(16 * mm, H - 11.6 * mm, W - 16 * mm, H - 11.6 * mm)
        # پاورقی
        canv.setStrokeColor(ACCENT_LINE); canv.setLineWidth(0.6)
        canv.line(16 * mm, 11.5 * mm, W - 16 * mm, 11.5 * mm)
        canv.setFillColor(ACCENT); canv.setFont('Vazirmatn-SemiBold', 8.2)
        canv.drawRightString(W - 16 * mm, 7.6 * mm, 'صفحهٔ ' + fa_digits(doc.page), direction='rtl', shaping=True)
        canv.saveState()
        canv.translate(W / 2, 8.3 * mm); canv.rotate(45)
        canv.setFillColor(GOLD); canv.rect(-2.4, -2.4, 4.8, 4.8, stroke=0, fill=1)
        canv.restoreState()
        canv.setFillColor(MUTED); canv.setFont('Vazirmatn-Medium', 6.2)
        canv.drawString(16 * mm, 7.6 * mm, 'kamandbeauty/Ideal')
        canv.restoreState()
    return on_page

plain_fa = clean_markup  # متادیتا و Outline با یونیکد منطقی

# ---------------------------------------------------------------- ساخت سند
class FaDocTemplate(BaseDocTemplate):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.heading_entries = []  # (level, text, page)
        self._hcount = 0

    def afterFlowable(self, flowable):
        if isinstance(flowable, PersianParagraph) and flowable._kind in ('h1', 'h2', 'h3'):
            self._hcount += 1
            level = {'h1': 0, 'h2': 1, 'h3': 2}[flowable._kind]
            text = flowable.getPlainText()
            key = 'sec-%d' % self._hcount
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(text, key, level, 0)
            self.heading_entries.append((level, text, self.page))

_AT = re.compile(r'^@([A-Za-z_][\w-]*)\s*:\s*(.*)$')
_H = re.compile(r'^(#{1,3})\s+(.*)$')
_ULI = re.compile(r'^\s*[-*]\s+')
_OLI = re.compile(r'^\s*(\d+)\.\s+')

def parse_markdown(path):
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')

    meta, i = {}, 0
    while i < len(lines):
        m = _AT.match(lines[i].strip())
        if not m:
            break
        meta[m.group(1).strip().lower()] = m.group(2).strip()
        i += 1

    blocks, buf, code, in_code = [], [], [], False

    def flush_par():
        if buf:
            blocks.append(('p', ' '.join(x.strip() for x in buf)))
            buf.clear()

    for ln in lines[i:]:
        s = ln.rstrip()
        st = s.strip()
        if st.startswith('```'):
            if in_code:
                blocks.append(('code', '\n'.join(code))); code, in_code = [], False
            else:
                flush_par(); in_code = True
            continue
        if in_code:
            code.append(ln); continue
        if st == '':
            flush_par(); continue
        m = _H.match(st)
        if m:
            flush_par(); blocks.append(('h' + str(len(m.group(1))), m.group(2).strip())); continue
        if st in ('---', '[pagebreak]'):
            flush_par(); blocks.append(('pagebreak', '')); continue
        if st == '[TOC]':
            flush_par(); blocks.append(('toc', '')); continue
        if st.startswith('> '):
            flush_par(); blocks.append(('quote', st[2:].strip())); continue
        if _ULI.match(ln):
            flush_par(); blocks.append(('li', _ULI.sub('', ln).strip())); continue
        m = _OLI.match(ln)
        if m:
            flush_par(); blocks.append(('oli', _OLI.sub('', ln).strip())); continue
        if st.startswith('|'):
            flush_par(); blocks.append(('tableline', st)); continue
        buf.append(s)

    flush_par()
    if in_code:
        blocks.append(('code', '\n'.join(code)))

    merged = []
    for kind, body in blocks:
        if merged and merged[-1][0] == kind and kind in ('li', 'oli', 'quote', 'tableline'):
            sep = '\n' if kind in ('li', 'oli', 'tableline') else ' '
            merged[-1] = (kind, merged[-1][1] + sep + body)
        else:
            merged.append((kind, body))
    return meta, merged

def build(md_path, pdf_path, toc_entries=None):
    register_fonts()
    styles = make_styles()
    meta, blocks = parse_markdown(md_path)

    W, H = A5
    ML, MR, MT, MB = 16 * mm, 16 * mm, 17 * mm, 17 * mm
    frame = Frame(ML, MB, W - ML - MR, H - MT - MB, id='body',
                  leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
    cover_frame = Frame(0, 0, W, H, id='cover',
                        leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)

    doc = FaDocTemplate(pdf_path, pagesize=A5,
                        title=plain_fa(meta.get('title', 'Ideal')),
                        author=plain_fa(meta.get('translator', 'ترجمهٔ فارسی')),
                        subject='نسخهٔ فارسی', creator='Ideal')

    def cover_page(canv, doc_):
        draw_cover(canv, doc_, meta)

    doc.addPageTemplates([
        PageTemplate(id='cover', frames=[cover_frame], onPage=cover_page),
        PageTemplate(id='content', frames=[frame],
                     onPage=make_content_furniture(meta)),
    ])

    story = [Spacer(1, 1),
             NextPageTemplate('content'),
             PageBreak()]

    if toc_entries:
        story.append(_para('فهرست مطالب', styles['TOCTitle'], kind='toch'))
        rows = []
        for level, text, page in toc_entries:
            if level > 1:
                continue
            indent = '' if level == 0 else '    '
            title_p = _para(indent + text, styles['TOC1' if level == 0 else 'TOC2'])
            page_p = Paragraph('<font color="#6D28D9"><b>%s</b></font>' % fa_digits(page),
                               ParagraphStyle('tocpage', fontName='Vazirmatn-Bold',
                                              fontSize=10.5, leading=19,
                                              alignment=TA_LEFT))
            rows.append([title_p, page_p])
        t = Table(rows, colWidths=[A5[0] - 32 * mm - 26, 26])
        t.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LINEBELOW', (0, 0), (-1, -2), 0.4, ACCENT_LINE),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ]))
        story.append(t)
        story.append(PageBreak())

    for kind, body in blocks:
        if kind == 'p':
            story.append(_para(body, styles['Body']))
        elif kind in ('h1', 'h2', 'h3'):
            style_name = kind.upper()
            heading = _para(body, styles[style_name], kind=kind)
            if kind == 'h1':
                story.append(KeepTogether([
                    heading,
                    HRFlowable(width='100%', thickness=1.1, color=GOLD,
                               spaceBefore=1, spaceAfter=10, hAlign='CENTER'),
                ]))
            else:
                story.append(heading)
        elif kind == 'quote':
            story.append(Spacer(1, 3))
            story.append(_quote_box(body, styles))
            story.append(Spacer(1, 9))
        elif kind == 'code':
            story.append(Spacer(1, 3))
            story.append(_code_box(body, styles))
            story.append(Spacer(1, 9))
        elif kind == 'li':
            story.extend(_list_flowables(body, styles, ordered=False))
        elif kind == 'oli':
            story.extend(_list_flowables(body, styles, ordered=True))
        elif kind == 'tableline':
            story.append(Spacer(1, 3))
            story.append(_table_flowable(body, styles))
            story.append(Spacer(1, 10))
        elif kind == 'pagebreak':
            story.append(PageBreak())
        elif kind == 'toc':
            pass  # فهرست قبل از محتوا افزوده می‌شود

    snap = []
    for i, f in enumerate(story):
        try:
            t = f.getPlainText()[:70] if hasattr(f, 'getPlainText') else ''
        except Exception:
            t = '<getPlainText failed>'
        snap.append('FLOW [%02d] %-16s %s' % (i, type(f).__name__, t))
    try:
        doc.build(story)
    except Exception:
        with open('/tmp/flowdump.txt', 'w', encoding='utf-8') as fh:
            fh.write('\n'.join(snap))
        raise
    return doc.heading_entries
