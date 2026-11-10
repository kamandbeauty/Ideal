package app.subflow.export

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Paints one caption frame at a time as a full-frame transparent bitmap.
 *
 * Design notes that matter:
 *
 *  * The bitmap is always the size of the *output* frame, and a single overlay
 *    covers the frame 1:1, so no anchor/scale maths can drift: caption position
 *    is expressed in the same normalised `positionY`/`widthFraction` units the
 *    Flutter painter uses.
 *  * Bitmaps are produced per (cue, active word, animation step) state and kept
 *    in a tiny LRU. `BitmapOverlay` re-uploads a texture when the bitmap object
 *    identity changes, so returning a *cached instance* is what keeps long
 *    exports cheap - a naive "new bitmap per frame" would upload 1080p textures
 *    30 times a second.
 *  * This is a port of `CaptionRenderer`, layer for layer: background box,
 *    glow, shadow, stroke, fill, then the active-word decoration. The two
 *    renderers share `CaptionPreset` and nothing else, which is why the export
 *    looks like the editor instead of "close enough".
 */
internal class CaptionFramePainter(
    context: Context,
    private val look: CaptionLook,
    private val frameW: Int,
    private val frameH: Int,
    private val cues: List<ExportCue>,
    /** Media3 reports presentation timestamps relative to the trimmed clip. */
    private val sourceOffsetUs: Long,
) {

    private val typeface: Typeface = FontAssets.resolve(context, look.fontFamily, look.fontWeight)
    private val shortEdge = min(frameW, frameH).toFloat()
    private val fontPx = (look.fontScale * shortEdge).coerceIn(8f, frameH * 0.42f)

    /**
     * Pixel-valued style fields (stroke, shadow offset, glow, box radius) are
     * authored against the editor stage, which is ~390 dp wide. Scaling them by
     * how much the frame grew is what makes a 2.5 px outline look like the
     * preview instead of vanishing at 1080p.
     */
    private val pxScale = shortEdge / 390f

    private val empty: Bitmap = Bitmap.createBitmap(frameW, frameH, Bitmap.Config.ARGB_8888)

    /**
     * A 1080p ARGB frame is ~8 MB, so the cache is deliberately tiny and even
     * smaller for 4K sources: re-rendering one caption state is far cheaper than
     * being killed by the low-memory killer mid-export.
     */
    private val cacheLimit = if (frameW.toLong() * frameH > 2_100_000L) 3 else 6

    private val cache = object : LinkedHashMap<String, Bitmap>(8, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Bitmap>?): Boolean =
            size > cacheLimit
    }

    fun bitmapFor(presentationTimeUs: Long): Bitmap {
        val timeUs = presentationTimeUs + sourceOffsetUs
        val index = cueIndexAt(timeUs)
        if (index < 0) return empty
        val cue = cues[index]
        val progress = enterProgress(cue, timeUs)
        val step = if (look.enter == "none") 0 else (progress * 8f).roundToInt()
        val active = activeWordIndex(cue, timeUs)
        val key = "$index|$step|$active"
        synchronized(cache) { cache[key]?.let { return it } }
        val bitmap = render(cue, timeUs, progress, active)
        synchronized(cache) { cache[key] = bitmap }
        return bitmap
    }

    // ------------------------------------------------------------- timeline

    private fun cueIndexAt(timeUs: Long): Int {
        var low = 0
        var high = cues.size - 1
        var found = -1
        while (low <= high) {
            val mid = (low + high) ushr 1
            val cue = cues[mid]
            when {
                timeUs < cue.startUs -> high = mid - 1
                timeUs >= cue.endUs -> low = mid + 1
                else -> {
                    found = mid
                    break
                }
            }
        }
        return found
    }

    private fun activeWordIndex(cue: ExportCue, timeUs: Long): Int {
        if (look.wordEffect == "none" || cue.words.isEmpty()) return -1
        cue.words.forEachIndexed { index, word ->
            if (timeUs >= word.startUs && timeUs < word.endUs) return index
            if (timeUs < word.startUs) return -1
        }
        // Past the last word: keep the final word highlighted instead of
        // dropping the decoration for the last frames of the cue.
        return if (timeUs >= cue.words.last().endUs) cue.words.size - 1 else -1
    }

    private fun enterProgress(cue: ExportCue, timeUs: Long): Float {
        if (look.enter == "none") return 1f
        val durationUs = look.durationMs.coerceAtLeast(1) * 1000L
        return ((timeUs - cue.startUs).toFloat() / durationUs).coerceIn(0f, 1f)
    }

    private fun ease(p: Float): Float = when (look.easing) {
        "linear" -> p
        "easeinout" -> if (p < 0.5f) 4f * p * p * p else 1f - (-2f * p + 2f).pow(3) / 2f
        "easeoutback" -> {
            val c = 1.70158f
            val t = p - 1f
            1f + (c + 1f) * t * t * t + c * t * t
        }
        "easeoutelastic" -> if (p <= 0f || p >= 1f) {
            p
        } else {
            val c = (2.0 * Math.PI / 3.0).toFloat()
            2f.pow(-10f * p) * sin((p * 10f - 0.75f) * c) + 1f
        }
        "easeinquad" -> p * p
        else -> 1f - (1f - p).pow(3)
    }

    // -------------------------------------------------------------- painting

    private fun render(cue: ExportCue, timeUs: Long, progress: Float, active: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(frameW, frameH, Bitmap.Config.ARGB_8888)
        val body = visibleText(cue, progress)
        if (body.isBlank()) return bitmap

        val eased = ease(progress)
        var alpha = 1f
        var scale = 1f
        var rotation = 0f
        var dx = 0f
        var dy = 0f
        val k = look.intensity.coerceIn(0.2f, 2.5f)
        val travel = 0.09f * shortEdge * k
        when (look.enter) {
            "fade" -> alpha *= eased
            "slideup" -> {
                dy += (1f - eased) * travel
                alpha *= eased
            }
            "slidedown" -> {
                dy -= (1f - eased) * travel
                alpha *= eased
            }
            "slideleft" -> {
                dx += (1f - eased) * travel
                alpha *= eased
            }
            "slideright" -> {
                dx -= (1f - eased) * travel
                alpha *= eased
            }
            "zoomin" -> {
                scale *= (0.6f + 0.4f * eased)
                alpha *= eased
            }
            "zoomout" -> {
                scale *= (1.4f - 0.4f * eased)
                alpha *= eased
            }
            "pop" -> scale *= 0.55f + 0.45f * eased
            "bounce" -> scale *= 0.7f + 0.3f * eased + 0.06f * sin(eased * Math.PI.toFloat() * 2f) * (1f - eased)
            "rotate" -> {
                rotation += (1f - eased) * 8f
                alpha *= eased
            }
            "blurin" -> alpha *= eased
            "elastic" -> scale *= 0.7f + 0.3f * (1f - (1f - eased).pow(3))
            "shake" -> dx += sin(eased * Math.PI.toFloat() * 6f) * (1f - eased) * 0.03f * shortEdge
            "glowpulse" -> alpha *= 0.4f + 0.6f * eased
            else -> Unit // none, typewriter, wordreveal: text cutting already applied
        }
        if (alpha <= 0.01f) return bitmap

        val layoutWidth = max(1, (frameW * look.widthFraction).roundToInt())
        val fillPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = this@CaptionFramePainter.typeface
            textSize = fontPx
            letterSpacing = if (fontPx > 0f) look.letterSpacing / fontPx else 0f
            color = look.textColor
        }
        val lineHeight = look.lineHeight
        fun layoutWith(paint: TextPaint): StaticLayout = StaticLayout.Builder
            .obtain(body, 0, body.length, paint, layoutWidth)
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .setTextDirection(if (look.rtl) TextDirectionHeuristics.RTL else TextDirectionHeuristics.LTR)
            .setIncludePad(false)
            .setLineSpacing(0f, lineHeight)
            .build()

        val fill = layoutWith(fillPaint)
        val boxHeight = fill.height.toFloat()
        val top = (frameH * look.positionY - boxHeight / 2f)
            .coerceIn(0f, max(0f, frameH - boxHeight))
        val left = (frameW - layoutWidth) / 2f

        var contentLeft = Float.MAX_VALUE
        var contentRight = -Float.MAX_VALUE
        for (line in 0 until fill.lineCount) {
            contentLeft = min(contentLeft, left + fill.getLineLeft(line))
            contentRight = max(contentRight, left + fill.getLineRight(line))
        }
        if (contentLeft > contentRight) {
            contentLeft = left
            contentRight = left + layoutWidth
        }
        val textRect = RectF(contentLeft, top, contentRight, top + boxHeight)
        val centerX = textRect.centerX()
        val centerY = textRect.centerY()

        val canvas = Canvas(bitmap)
        canvas.save()
        canvas.translate(centerX + dx, centerY + dy)
        if (rotation != 0f) canvas.rotate(rotation)
        if (scale != 1f) canvas.scale(scale, scale)
        canvas.translate(-centerX, -centerY)
        if (alpha < 0.999f) {
            canvas.saveLayerAlpha(null, (alpha.coerceIn(0f, 1f) * 255f).roundToInt())
        }

        if (look.boxBackground) {
            val pad = fontPx * 0.28f
            val radius = if (look.backgroundRadius <= 0f) fontPx * 0.15f else look.backgroundRadius * pxScale
            val box = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = withAlpha(look.backgroundColor, look.backgroundOpacity)
            }
            canvas.drawRoundRect(
                RectF(textRect.left - pad, textRect.top - pad, textRect.right + pad, textRect.bottom + pad),
                radius,
                radius,
                box,
            )
        }

        if (active >= 0) {
            drawActiveWord(canvas, fill, body, active, cue, timeUs, left, top)
        }

        if (look.glowRadius > 0f) {
            val glowPaint = TextPaint(fillPaint).apply {
                color = look.glowColor
                maskFilter = BlurMaskFilter(max(1f, look.glowRadius * pxScale * 0.45f), BlurMaskFilter.Blur.NORMAL)
            }
            canvas.save()
            canvas.translate(left, top)
            layoutWith(glowPaint).draw(canvas)
            canvas.restore()
        }

        if (look.shadowBlur > 0f) {
            val shadowPaint = TextPaint(fillPaint).apply {
                color = look.shadowColor
                setShadowLayer(
                    max(0.5f, look.shadowBlur * pxScale * 0.3f),
                    0f,
                    look.shadowOffsetY * pxScale,
                    look.shadowColor,
                )
            }
            canvas.save()
            canvas.translate(left, top)
            layoutWith(shadowPaint).draw(canvas)
            canvas.restore()
        }

        if (look.strokeWidth > 0f) {
            val strokePaint = TextPaint(fillPaint).apply {
                color = look.strokeColor
                style = Paint.Style.STROKE
                strokeWidth = look.strokeWidth * pxScale
                strokeJoin = Paint.Join.ROUND
                strokeCap = Paint.Cap.ROUND
            }
            canvas.save()
            canvas.translate(left, top)
            layoutWith(strokePaint).draw(canvas)
            canvas.restore()
        }

        val gradientEnd: Int? = look.gradientEnd
        if (gradientEnd != null) {
            fillPaint.shader = LinearGradient(
                0f,
                top,
                0f,
                top + boxHeight,
                intArrayOf(look.textColor, gradientEnd),
                null,
                Shader.TileMode.CLAMP,
            )
        }

        canvas.save()
        canvas.translate(left, top)
        fill.draw(canvas)
        canvas.restore()

        if (alpha < 0.999f) canvas.restore()
        canvas.restore()
        return bitmap
    }

    /**
     * Active-word decoration. Word rectangles come from the layout itself
     * (`getLineForOffset` + `getPrimaryHorizontal`), so a highlight lands under
     * the right glyph in RTL as well - the bug that made an earlier gallery
     * build park the highlight in the middle of the line.
     */
    private fun drawActiveWord(
        canvas: Canvas,
        layout: StaticLayout,
        body: String,
        active: Int,
        cue: ExportCue,
        timeUs: Long,
        left: Float,
        top: Float,
    ) {
        val ranges = wordRanges(body)
        if (ranges.isEmpty()) return
        val index = min(active, ranges.size - 1)
        val range = ranges[index]
        val start = range.first
        val end = (range.second).coerceAtMost(body.length)
        if (start >= end) return
        val line = layout.getLineForOffset(start)
        val x0 = left + layout.getPrimaryHorizontal(start)
        val x1 = left + layout.getPrimaryHorizontal(end)
        val wordRect = RectF(
            min(x0, x1),
            top + layout.getLineTop(line),
            max(x0, x1),
            top + layout.getLineBottom(line),
        )
        if (wordRect.width() <= 0f) return
        val accent = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = look.accentColor }

        when (look.wordEffect) {
            "activebackground" -> {
                val pad = fontPx * 0.12f
                val radius = fontPx * 0.16f
                accent.alpha = (0.92f * 255f).roundToInt()
                canvas.drawRoundRect(
                    RectF(
                        wordRect.left - pad,
                        wordRect.top - pad,
                        wordRect.right + pad,
                        wordRect.bottom + pad,
                    ),
                    radius,
                    radius,
                    accent,
                )
            }
            "activeunderline" -> {
                val thickness = max(2f, fontPx * 0.09f)
                canvas.drawRoundRect(
                    RectF(
                        wordRect.left,
                        wordRect.bottom + thickness * 0.6f,
                        wordRect.right,
                        wordRect.bottom + thickness * 1.6f,
                    ),
                    thickness,
                    thickness,
                    accent,
                )
            }
            "karaokefill" -> {
                val word = cue.words.getOrNull(index)
                val fraction = if (word == null || word.endUs <= word.startUs) {
                    1f
                } else {
                    ((timeUs - word.startUs).toFloat() / (word.endUs - word.startUs)).coerceIn(0f, 1f)
                }
                canvas.save()
                if (look.rtl) {
                    canvas.clipRect(wordRect.right - wordRect.width() * fraction, wordRect.top, wordRect.right, wordRect.bottom)
                } else {
                    canvas.clipRect(wordRect.left, wordRect.top, wordRect.left + wordRect.width() * fraction, wordRect.bottom)
                }
                drawAccentText(canvas, body, accent, left, top)
                canvas.restore()
            }
            // activeColor / activeScale / wordPop / neighborDim all end up as
            // "this word carries the accent colour"; the scale variants are
            // deliberately flattened so a burned-in word never jumps in size
            // from one frame to the next.
            "activecolor", "activescale", "wordpop", "neighbordim" -> {
                canvas.save()
                canvas.clipRect(wordRect)
                drawAccentText(canvas, body, accent, left, top)
                canvas.restore()
            }
            else -> Unit
        }
    }

    private fun drawAccentText(
        canvas: Canvas,
        body: String,
        paint: Paint,
        left: Float,
        top: Float,
    ) {
        val accentLayout = StaticLayout.Builder
            .obtain(body, 0, body.length, TextPaint(paint).apply {
                typeface = this@CaptionFramePainter.typeface
                textSize = fontPx
                letterSpacing = if (fontPx > 0f) look.letterSpacing / fontPx else 0f
            }, max(1, (frameW * look.widthFraction).roundToInt()))
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .setTextDirection(if (look.rtl) TextDirectionHeuristics.RTL else TextDirectionHeuristics.LTR)
            .setIncludePad(false)
            .setLineSpacing(0f, look.lineHeight)
            .build()
        canvas.save()
        canvas.translate(left, top)
        accentLayout.draw(canvas)
        canvas.restore()
    }

    private fun withAlpha(color: Int, opacity: Float): Int {
        val alpha = ((color ushr 24) and 0xFF) * opacity.coerceIn(0f, 1f)
        return (alpha.roundToInt() shl 24) or (color and 0x00FFFFFF)
    }

    // ---------------------------------------------------------------- text

    /**
     * The text actually visible at this instant. `typewriter` and `wordReveal`
     * are real animations, not decoration, so they are reproduced here instead
     * of rendering the full line early.
     */
    private fun visibleText(cue: ExportCue, progress: Float): String {
        val display = if (look.uppercase) cue.text.uppercase() else cue.text
        val eased = ease(progress)
        return when (look.enter) {
            "typewriter" -> {
                val budget = floor(display.length * eased).toInt().coerceIn(0, display.length)
                display.substring(0, budget)
            }
            "wordreveal" -> {
                val words = wordRanges(display)
                if (words.isEmpty()) return display
                val limit = ceil(words.size * eased).toInt().coerceIn(0, words.size)
                val builder = StringBuilder(display)
                for (i in limit until words.size) {
                    for (c in words[i].first until words[i].second) builder.setCharAt(c, ' ')
                }
                builder.toString()
            }
            else -> display
        }
    }

    /** Character ranges of the whitespace-separated words in [text]. */
    private fun wordRanges(text: String): List<Pair<Int, Int>> {
        val ranges = ArrayList<Pair<Int, Int>>()
        var index = 0
        while (index < text.length) {
            if (text[index].isWhitespace()) {
                index++
                continue
            }
            val start = index
            while (index < text.length && !text[index].isWhitespace()) index++
            ranges.add(start to index)
        }
        return ranges
    }
}
