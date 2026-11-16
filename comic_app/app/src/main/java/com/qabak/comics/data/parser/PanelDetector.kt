package com.qabak.comics.data.parser

import android.graphics.Bitmap
import android.graphics.Color
import com.qabak.comics.model.PanelRect
import kotlin.math.abs

/**
 * Automatic recursive XY-cut comic panel detector for Guided Panel-by-Panel reading mode.
 * Finds clean white/cream or black/dark gutters separating comic panels on imported CBZ, CBR, PDF,
 * and image pages, ordering panels either RTL (Persian / Manga) or LTR (Western comics).
 */
object PanelDetector {

    private const val MIN_PANEL_FRACTION = 0.16f
    private const val MIN_GUTTER_PX = 4
    private const val MAX_UNIFORM_DIFF = 22
    private const val UNIFORM_RATIO_THRESHOLD = 0.91f
    private const val MAX_DEPTH = 4

    fun detectPanels(bitmap: Bitmap, rtlOrder: Boolean): List<PanelRect> {
        val w = bitmap.width
        val h = bitmap.height
        if (w < 80 || h < 80) {
            return listOf(PanelRect(0f, 0f, 1f, 1f))
        }

        // Sample border gutter color from the outermost 3px margin median
        val gutterLuma = estimateGutterLuma(bitmap)
        val trimmed = trimOuterMargin(bitmap, 0, 0, w, h, gutterLuma)

        val rawRects = mutableListOf<IntBox>()
        splitRecursive(
            bitmap = bitmap,
            box = trimmed,
            gutterLuma = gutterLuma,
            rtlOrder = rtlOrder,
            depth = 0,
            out = rawRects
        )

        val filtered = rawRects.filter { box ->
            box.width.toFloat() / w >= MIN_PANEL_FRACTION &&
                box.height.toFloat() / h >= MIN_PANEL_FRACTION
        }

        if (filtered.size <= 1) {
            // For full-bleed splash pages, provide top-half & bottom-half guided stops if tall portrait
            return if (h > w * 1.25f) {
                listOf(
                    PanelRect(0.0f, 0.0f, 1.0f, 0.54f),
                    PanelRect(0.0f, 0.46f, 1.0f, 1.0f)
                )
            } else {
                listOf(PanelRect(0f, 0f, 1f, 1f))
            }
        }

        return filtered.map { box ->
            PanelRect(
                left = (box.x1.toFloat() / w).coerceIn(0f, 0.95f),
                top = (box.y1.toFloat() / h).coerceIn(0f, 0.95f),
                right = (box.x2.toFloat() / w).coerceIn(0.05f, 1f),
                bottom = (box.y2.toFloat() / h).coerceIn(0.05f, 1f)
            )
        }
    }

    private data class IntBox(val x1: Int, val y1: Int, val x2: Int, val y2: Int) {
        val width: Int get() = x2 - x1
        val height: Int get() = y2 - y1
    }

    private fun splitRecursive(
        bitmap: Bitmap,
        box: IntBox,
        gutterLuma: Int,
        rtlOrder: Boolean,
        depth: Int,
        out: MutableList<IntBox>
    ) {
        if (depth >= MAX_DEPTH) {
            out.add(box)
            return
        }
        val minW = (bitmap.width * MIN_PANEL_FRACTION).toInt()
        val minH = (bitmap.height * MIN_PANEL_FRACTION).toInt()

        // 1. Try horizontal gutter split first (comic pages read row-by-row top-to-bottom)
        val hSplits = findHorizontalGutters(bitmap, box, gutterLuma, minH)
        if (hSplits.isNotEmpty()) {
            var curY = box.y1
            for ((gStart, gEnd) in hSplits) {
                if (gStart - curY >= minH) {
                    val sub = trimOuterMargin(bitmap, box.x1, curY, box.x2, gStart, gutterLuma)
                    splitRecursive(bitmap, sub, gutterLuma, rtlOrder, depth + 1, out)
                }
                curY = gEnd
            }
            if (box.y2 - curY >= minH) {
                val sub = trimOuterMargin(bitmap, box.x1, curY, box.x2, box.y2, gutterLuma)
                splitRecursive(bitmap, sub, gutterLuma, rtlOrder, depth + 1, out)
            }
            return
        }

        // 2. Try vertical gutter split inside a row (ordered RTL or LTR)
        val vSplits = findVerticalGutters(bitmap, box, gutterLuma, minW)
        if (vSplits.isNotEmpty()) {
            val cols = mutableListOf<IntBox>()
            var curX = box.x1
            for ((gStart, gEnd) in vSplits) {
                if (gStart - curX >= minW) {
                    cols.add(trimOuterMargin(bitmap, curX, box.y1, gStart, box.y2, gutterLuma))
                }
                curX = gEnd
            }
            if (box.x2 - curX >= minW) {
                cols.add(trimOuterMargin(bitmap, curX, box.y1, box.x2, box.y2, gutterLuma))
            }
            val ordered = if (rtlOrder) cols.asReversed() else cols
            for (col in ordered) {
                splitRecursive(bitmap, col, gutterLuma, rtlOrder, depth + 1, out)
            }
            return
        }

        out.add(box)
    }

    private fun findHorizontalGutters(
        bitmap: Bitmap,
        box: IntBox,
        gutterLuma: Int,
        minPanelH: Int
    ): List<Pair<Int, Int>> {
        val startY = box.y1 + minPanelH
        val endY = box.y2 - minPanelH
        if (startY >= endY) return emptyList()

        val gutters = mutableListOf<Pair<Int, Int>>()
        var runStart = -1
        for (y in startY until endY) {
            if (isRowGutter(bitmap, box.x1, box.x2, y, gutterLuma)) {
                if (runStart < 0) runStart = y
            } else if (runStart >= 0) {
                if (y - runStart >= MIN_GUTTER_PX) {
                    gutters.add(runStart to y)
                }
                runStart = -1
            }
        }
        if (runStart >= 0 && endY - runStart >= MIN_GUTTER_PX) {
            gutters.add(runStart to endY)
        }
        return gutters
    }

    private fun findVerticalGutters(
        bitmap: Bitmap,
        box: IntBox,
        gutterLuma: Int,
        minPanelW: Int
    ): List<Pair<Int, Int>> {
        val startX = box.x1 + minPanelW
        val endX = box.x2 - minPanelW
        if (startX >= endX) return emptyList()

        val gutters = mutableListOf<Pair<Int, Int>>()
        var runStart = -1
        for (x in startX until endX) {
            if (isColGutter(bitmap, x, box.y1, box.y2, gutterLuma)) {
                if (runStart < 0) runStart = x
            } else if (runStart >= 0) {
                if (x - runStart >= MIN_GUTTER_PX) {
                    gutters.add(runStart to x)
                }
                runStart = -1
            }
        }
        if (runStart >= 0 && endX - runStart >= MIN_GUTTER_PX) {
            gutters.add(runStart to endX)
        }
        return gutters
    }

    private fun trimOuterMargin(
        bitmap: Bitmap,
        x1: Int,
        y1: Int,
        x2: Int,
        y2: Int,
        gutterLuma: Int
    ): IntBox {
        var top = y1
        var bottom = y2
        var left = x1
        var right = x2
        val maxTrimY = (y2 - y1) / 5
        val maxTrimX = (x2 - x1) / 5

        while (top < y1 + maxTrimY && isRowGutter(bitmap, left, right, top, gutterLuma)) top++
        while (bottom > y2 - maxTrimY && isRowGutter(bitmap, left, right, bottom - 1, gutterLuma)) bottom--
        while (left < x1 + maxTrimX && isColGutter(bitmap, left, top, bottom, gutterLuma)) left++
        while (right > x2 - maxTrimX && isColGutter(bitmap, right - 1, top, bottom, gutterLuma)) right--

        return if (right - left > 20 && bottom - top > 20) IntBox(left, top, right, bottom)
        else IntBox(x1, y1, x2, y2)
    }

    private fun isRowGutter(bitmap: Bitmap, x1: Int, x2: Int, y: Int, gutterLuma: Int): Boolean {
        val span = x2 - x1
        if (span <= 8) return false
        val step = (span / 64).coerceAtLeast(1)
        var total = 0
        var matches = 0
        var x = x1 + 2
        while (x < x2 - 2) {
            total++
            if (abs(pixelLuma(bitmap.getPixel(x, y)) - gutterLuma) <= MAX_UNIFORM_DIFF) {
                matches++
            }
            x += step
        }
        return total > 0 && matches.toFloat() / total >= UNIFORM_RATIO_THRESHOLD
    }

    private fun isColGutter(bitmap: Bitmap, x: Int, y1: Int, y2: Int, gutterLuma: Int): Boolean {
        val span = y2 - y1
        if (span <= 8) return false
        val step = (span / 64).coerceAtLeast(1)
        var total = 0
        var matches = 0
        var y = y1 + 2
        while (y < y2 - 2) {
            total++
            if (abs(pixelLuma(bitmap.getPixel(x, y)) - gutterLuma) <= MAX_UNIFORM_DIFF) {
                matches++
            }
            y += step
        }
        return total > 0 && matches.toFloat() / total >= UNIFORM_RATIO_THRESHOLD
    }

    private fun estimateGutterLuma(bitmap: Bitmap): Int {
        val samples = ArrayList<Int>(128)
        val w = bitmap.width
        val h = bitmap.height
        val stepX = (w / 32).coerceAtLeast(1)
        val stepY = (h / 32).coerceAtLeast(1)
        var x = 2
        while (x < w - 2) {
            samples.add(pixelLuma(bitmap.getPixel(x, 2)))
            samples.add(pixelLuma(bitmap.getPixel(x, h - 3)))
            x += stepX
        }
        var y = 2
        while (y < h - 2) {
            samples.add(pixelLuma(bitmap.getPixel(2, y)))
            samples.add(pixelLuma(bitmap.getPixel(w - 3, y)))
            y += stepY
        }
        if (samples.isEmpty()) return 250
        samples.sort()
        return samples[samples.size / 2]
    }

    private fun pixelLuma(argb: Int): Int {
        val r = Color.red(argb)
        val g = Color.green(argb)
        val b = Color.blue(argb)
        return (r * 299 + g * 587 + b * 114) / 1000
    }
}
