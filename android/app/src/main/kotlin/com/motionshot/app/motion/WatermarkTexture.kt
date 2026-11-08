package com.motionshot.app.motion

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface

/**
 * Renders the watermark into a full-viewport, premultiplied bitmap.
 *
 * Why full viewport: the overlay is then drawn with the exact same
 * `cameraMatrix` + `drawLayer` path every photo uses (identity camera),
 * which keeps the GL code minimal and the orientation behaviour identical
 * to the (golden-verified) photo path. Cost: one output-sized bitmap.
 *
 * Layout mirrors the Dart preview painter (`MotionPreview._paintWatermark`):
 *  * text height = fontScale * outputHeight
 *  * dark chip: black at 0.45 * opacity, padding 0.5x/0.3x of the font size,
 *    corner radius 0.3x
 *  * white text at [opacity], bold
 *  * 2% margin from the edges, anchored by the 3x3 grid position
 *
 * Pixels are premultiplied on the CPU because the layer shader expects
 * premultiplied colour (photos are opaque so the distinction never matters
 * for them; it does for the watermark's semi-transparent pixels).
 */
object WatermarkTexture {

    /**
     * @return an [outputWidth] x [outputHeight] ARGB_8888 bitmap with the
     *         watermark (chip + text) at the spec's anchor, or null on
     *         allocation failure (the export proceeds without the watermark).
     */
    fun render(
        spec: WatermarkSpec,
        outputWidth: Int,
        outputHeight: Int,
    ): Bitmap? {
        val w = outputWidth
        val h = outputHeight
        val bitmap = try {
            Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        } catch (e: OutOfMemoryError) {
            null
        } ?: return null
        val canvas = Canvas(bitmap)

        val opacity = spec.opacity.coerceIn(0.0, 1.0)
        val fontSizePx = (spec.fontScale * outputHeight).toInt().coerceAtLeast(8)
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = fontSizePx.toFloat()
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
            color = Color.argb((opacity * 255).toInt(), 255, 255, 255)
        }
        val chipPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb((opacity * 0.45f * 255).toInt(), 0, 0, 0)
        }

        val bounds = Rect()
        textPaint.getTextBounds(spec.text, 0, spec.text.length, bounds)
        val padX = (fontSizePx * 0.5f).toInt()
        val padY = (fontSizePx * 0.3f).toInt()

        // The bitmap is exactly viewport-sized, so anything drawn beyond the
        // edges is clipped — the same behaviour as the preview's Canvas.
        val marginX = (w * 0.02f).toInt()
        val marginY = (h * 0.02f).toInt()
        val textW = bounds.width()
        val textH = bounds.height()
        val x: Int = when (spec.col) {
            0 -> marginX
            2 -> w - marginX - textW
            else -> (w - textW) / 2
        }
        val y: Int = when (spec.row) {
            0 -> marginY
            2 -> h - marginY - textH
            else -> (h - textH) / 2
        }

        canvas.drawRoundRect(
            (x - padX).toFloat(), (y - padY).toFloat(),
            (x + padX + textW).toFloat(), (y + padY + textH).toFloat(),
            (fontSizePx * 0.3f).toFloat(), (fontSizePx * 0.3f).toFloat(),
            chipPaint,
        )
        canvas.drawText(
            spec.text,
            (x - bounds.left).toFloat(),
            (y - bounds.top).toFloat(),
            textPaint,
        )

        premultiply(bitmap)
        return bitmap
    }

    private fun premultiply(bitmap: Bitmap) {
        val w = bitmap.width
        val h = bitmap.height
        val pixels = IntArray(w * h)
        bitmap.getPixels(pixels, 0, w, 0, 0, w, h)
        for (i in pixels.indices) {
            val p = pixels[i]
            val a = (p ushr 24) and 0xFF
            if (a == 255) continue
            if (a == 0) {
                pixels[i] = 0
                continue
            }
            val r = ((p ushr 16) and 0xFF) * a / 255
            val g = ((p ushr 8) and 0xFF) * a / 255
            val b = (p and 0xFF) * a / 255
            pixels[i] = (a shl 24) or (r shl 16) or (g shl 8) or b
        }
        bitmap.setPixels(pixels, 0, w, 0, 0, w, h)
    }
}
