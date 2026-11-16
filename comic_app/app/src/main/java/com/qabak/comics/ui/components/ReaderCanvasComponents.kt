package com.qabak.comics.ui.components

import android.graphics.Bitmap
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChanged
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.qabak.comics.model.AppLanguage
import com.qabak.comics.model.DialogueBubble
import com.qabak.comics.model.DialogueDisplayMode
import com.qabak.comics.model.PageFitMode
import com.qabak.comics.model.PanelRect
import com.qabak.comics.model.ReaderBackground
import com.qabak.comics.model.ReaderColorFilter
import com.qabak.comics.ui.i18n.LocalAppStrings
import com.qabak.comics.ui.theme.ComicAmber
import com.qabak.comics.ui.theme.ComicCrimson
import com.qabak.comics.ui.theme.ComicParchment
import kotlin.math.roundToInt

fun buildReaderColorFilter(mode: ReaderColorFilter): ColorFilter? {
    return when (mode) {
        ReaderColorFilter.NONE -> null
        ReaderColorFilter.GRAYSCALE -> {
            val cm = ColorMatrix().apply { setToSaturation(0f) }
            ColorFilter.colorMatrix(cm)
        }
        ReaderColorFilter.SEPIA -> {
            val matrix = ColorMatrix(
                floatArrayOf(
                    0.393f, 0.769f, 0.189f, 0f, 0f,
                    0.349f, 0.686f, 0.168f, 0f, 0f,
                    0.272f, 0.534f, 0.131f, 0f, 0f,
                    0f, 0f, 0f, 1f, 0f
                )
            )
            // Blend 65% sepia + 35% natural color for pleasant archival comic paper warmth
            val blended = FloatArray(20)
            val identity = ColorMatrix().values
            for (i in 0 until 20) {
                blended[i] = identity[i] * 0.35f + matrix.values[i] * 0.65f
            }
            ColorFilter.colorMatrix(ColorMatrix(blended))
        }
        ReaderColorFilter.HIGH_CONTRAST -> {
            val contrast = 1.18f
            val translate = (-0.5f * contrast + 0.5f) * 255f
            val matrix = ColorMatrix(
                floatArrayOf(
                    contrast, 0f, 0f, 0f, translate,
                    0f, contrast, 0f, 0f, translate,
                    0f, 0f, contrast, 0f, translate,
                    0f, 0f, 0f, 1f, 0f
                )
            )
            ColorFilter.colorMatrix(matrix)
        }
    }
}

fun readerBackgroundColor(bg: ReaderBackground): Color = when (bg) {
    ReaderBackground.BLACK -> Color(0xFF07090E)
    ReaderBackground.SEPIA -> Color(0xFFF2E8D5)
    ReaderBackground.WHITE -> Color(0xFFF7F8FA)
}

fun resolveDialogueLanguage(
    mode: DialogueDisplayMode,
    appLanguage: AppLanguage
): AppLanguage? = when (mode) {
    DialogueDisplayMode.MATCH_APP -> appLanguage
    DialogueDisplayMode.FA -> AppLanguage.FA
    DialogueDisplayMode.EN -> AppLanguage.EN
    DialogueDisplayMode.HIDDEN -> null
}

/**
 * Renders a comic page together with its localized graphic-novel speech bubbles & optional guided-panel frame.
 */
@Composable
fun ComicPageArtwork(
    bitmap: Bitmap,
    bubbles: List<DialogueBubble>,
    dialogueLanguage: AppLanguage?,
    colorFilter: ColorFilter?,
    highlightedPanel: PanelRect? = null,
    modifier: Modifier = Modifier
) {
    val ratio = remember(bitmap.width, bitmap.height) {
        (bitmap.width.toFloat() / bitmap.height.coerceAtLeast(1).toFloat()).coerceIn(0.3f, 3.0f)
    }

    // Use fixed LTR coordinate space so normalized (x, y) coordinates map directly to artwork pixels
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        BoxWithConstraints(
            modifier = modifier.aspectRatio(ratio)
        ) {
            val density = LocalDensity.current
            val boxW = constraints.maxWidth.toFloat()
            val boxH = constraints.maxHeight.toFloat()

            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.FillBounds,
                colorFilter = colorFilter,
                modifier = Modifier.fillMaxSize()
            )

            // Guided panel subtle golden highlight frame + dark surround mask
            if (highlightedPanel != null && (highlightedPanel.width < 0.96f || highlightedPanel.height < 0.96f)) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val px1 = highlightedPanel.left * size.width
                    val py1 = highlightedPanel.top * size.height
                    val px2 = highlightedPanel.right * size.width
                    val py2 = highlightedPanel.bottom * size.height
                    val mask = Color.Black.copy(alpha = 0.52f)
                    // Top, bottom, left, right masks around active panel
                    if (py1 > 0f) drawRect(mask, Offset(0f, 0f), Size(size.width, py1))
                    if (py2 < size.height) drawRect(mask, Offset(0f, py2), Size(size.width, size.height - py2))
                    if (px1 > 0f) drawRect(mask, Offset(0f, py1), Size(px1, py2 - py1))
                    if (px2 < size.width) drawRect(mask, Offset(px2, py1), Size(size.width - px2, py2 - py1))

                    drawRect(
                        color = ComicAmber,
                        topLeft = Offset(px1, py1),
                        size = Size(px2 - px1, py2 - py1),
                        style = Stroke(width = 2.5.dp.toPx())
                    )
                }
            }

            // Render crisp bilingual comic dialogue bubbles & captions
            if (dialogueLanguage != null && bubbles.isNotEmpty() && boxW > 100f && boxH > 100f) {
                val textDir = if (dialogueLanguage.isRtl) LayoutDirection.Rtl else LayoutDirection.Ltr
                bubbles.forEach { bubble ->
                    val mainText = bubble.textFor(dialogueLanguage)
                    if (mainText.isBlank()) return@forEach
                    val maxBubbleDp = with(density) { (boxW * bubble.width.coerceIn(0.25f, 0.88f)).toDp() }
                    val halfMaxPx = boxW * bubble.width.coerceIn(0.25f, 0.88f) * 0.5f
                    val leftPx = (bubble.x * boxW - halfMaxPx).coerceIn(boxW * 0.04f, boxW * 0.92f - halfMaxPx)
                    val topPx = (bubble.y * boxH - boxH * 0.045f).coerceIn(boxH * 0.025f, boxH * 0.91f)

                    Box(
                        modifier = Modifier
                            .offset { IntOffset(leftPx.roundToInt(), topPx.roundToInt()) }
                            .widthIn(max = maxBubbleDp)
                    ) {
                        CompositionLocalProvider(LocalLayoutDirection provides textDir) {
                            ComicBubbleItem(
                                bubble = bubble,
                                text = mainText,
                                subText = bubble.subFor(dialogueLanguage)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ComicBubbleItem(
    bubble: DialogueBubble,
    text: String,
    subText: String
) {
    when (bubble.style.uppercase()) {
        "COVER_TITLE" -> {
            Surface(
                shape = RoundedCornerShape(10.dp),
                color = Color(0xE00C101C),
                border = BorderStroke(1.5.dp, ComicAmber),
                modifier = Modifier.shadow(6.dp, RoundedCornerShape(10.dp))
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)
                ) {
                    Text(
                        text = text,
                        style = MaterialTheme.typography.titleSmall.copy(
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 13.5.sp,
                            lineHeight = 19.sp
                        ),
                        color = Color(0xFFFFF8E7),
                        textAlign = TextAlign.Center
                    )
                    if (subText.isNotBlank()) {
                        Spacer(Modifier.height(2.dp))
                        Text(
                            text = subText,
                            style = MaterialTheme.typography.labelSmall.copy(
                                fontSize = 9.5.sp,
                                letterSpacing = 0.4.sp
                            ),
                            color = ComicAmber,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }
        }

        "CAPTION" -> {
            Surface(
                shape = RoundedCornerShape(4.dp),
                color = ComicParchment.copy(alpha = 0.96f),
                border = BorderStroke(1.8.dp, Color(0xFF18161E)),
                modifier = Modifier.shadow(4.dp, RoundedCornerShape(4.dp))
            ) {
                Text(
                    text = text,
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 10.5.sp,
                        lineHeight = 15.5.sp
                    ),
                    color = Color(0xFF181512),
                    modifier = Modifier.padding(horizontal = 9.dp, vertical = 5.dp)
                )
            }
        }

        "SHOUT" -> {
            Surface(
                shape = RoundedCornerShape(10.dp),
                color = Color(0xFFFFF4D2),
                border = BorderStroke(2.2.dp, ComicCrimson),
                modifier = Modifier.shadow(5.dp, RoundedCornerShape(10.dp))
            ) {
                Text(
                    text = text,
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 10.8.sp,
                        lineHeight = 15.5.sp
                    ),
                    color = Color(0xFF1A0E12),
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                )
            }
        }

        "SFX" -> {
            Surface(
                shape = RoundedCornerShape(8.dp),
                color = ComicAmber,
                border = BorderStroke(2.dp, Color(0xFF111116)),
                modifier = Modifier
                    .rotate(-5f)
                    .shadow(4.dp, RoundedCornerShape(8.dp))
            ) {
                Text(
                    text = text,
                    style = MaterialTheme.typography.labelLarge.copy(
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 12.sp,
                        lineHeight = 15.sp
                    ),
                    color = Color(0xFF121016),
                    modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp)
                )
            }
        }

        else -> {
            // Classic comic SPEECH bubble with directional pointer tail
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                if (bubble.tailDir.equals("UP", ignoreCase = true)) {
                    SpeechTailCanvas(pointUp = true)
                }
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = Color.White.copy(alpha = 0.97f),
                    border = BorderStroke(1.8.dp, Color(0xFF14161F)),
                    modifier = Modifier.shadow(4.dp, RoundedCornerShape(16.dp))
                ) {
                    Text(
                        text = text,
                        style = MaterialTheme.typography.bodySmall.copy(
                            fontWeight = FontWeight.Medium,
                            fontSize = 10.5.sp,
                            lineHeight = 15.5.sp
                        ),
                        color = Color(0xFF12141C),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                    )
                }
                if (bubble.tailDir.equals("DOWN", ignoreCase = true)) {
                    SpeechTailCanvas(pointUp = false)
                }
            }
        }
    }
}

@Composable
private fun SpeechTailCanvas(pointUp: Boolean) {
    Canvas(modifier = Modifier.size(width = 14.dp, height = 7.dp)) {
        val path = Path().apply {
            if (pointUp) {
                moveTo(size.width * 0.55f, 0f)
                lineTo(size.width * 0.15f, size.height)
                lineTo(size.width * 0.85f, size.height)
            } else {
                moveTo(size.width * 0.15f, 0f)
                lineTo(size.width * 0.85f, 0f)
                lineTo(size.width * 0.45f, size.height)
            }
            close()
        }
        drawPath(path, Color.White)
        drawPath(path, Color(0xFF14161F), style = Stroke(width = 1.6.dp.toPx()))
    }
}

/**
 * Interactive single page viewport supporting:
 * - Pinch-to-zoom (1x..4x) & bounded pan without blocking HorizontalPager swipes at 1x
 * - Double-tap smart zoom (1x <-> 2.25x around tapped point)
 * - Left/Right edge tap-zone page navigation (auto-mirrored for RTL vs LTR) & center-tap HUD toggle
 * - Smooth spring-animated Guided Panel Zoom
 */
@Composable
fun ZoomableComicPage(
    bitmap: Bitmap?,
    isLoading: Boolean,
    bubbles: List<DialogueBubble>,
    dialogueLanguage: AppLanguage?,
    pageFitMode: PageFitMode,
    colorFilter: ColorFilter?,
    backgroundColor: Color,
    isRtlNavigation: Boolean,
    guidedPanel: PanelRect?,
    resetKey: Any,
    onCenterTap: () -> Unit,
    onNextTap: () -> Unit,
    onPrevTap: () -> Unit,
    modifier: Modifier = Modifier
) {
    val strings = LocalAppStrings.current
    var userScale by remember(resetKey) { mutableFloatStateOf(1f) }
    var userOffsetX by remember(resetKey) { mutableFloatStateOf(0f) }
    var userOffsetY by remember(resetKey) { mutableFloatStateOf(0f) }

    LaunchedEffect(guidedPanel) {
        if (guidedPanel != null) {
            userScale = 1f
            userOffsetX = 0f
            userOffsetY = 0f
        }
    }

    // Use fixed LTR inside viewport so physical left/right screen taps behave predictably
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        BoxWithConstraints(
            modifier = modifier
                .fillMaxSize()
                .background(backgroundColor)
                .clipToBounds()
                .pointerInput(isRtlNavigation, guidedPanel) {
                    detectTapGestures(
                        onDoubleTap = { tapOffset ->
                            if (guidedPanel != null) return@detectTapGestures
                            if (userScale > 1.15f) {
                                userScale = 1f
                                userOffsetX = 0f
                                userOffsetY = 0f
                            } else {
                                val targetScale = 2.25f
                                val cx = size.width * 0.5f
                                val cy = size.height * 0.5f
                                val maxX = size.width * (targetScale - 1f) * 0.5f
                                val maxY = size.height * (targetScale - 1f) * 0.5f
                                userScale = targetScale
                                userOffsetX = ((cx - tapOffset.x) * (targetScale - 1f)).coerceIn(-maxX, maxX)
                                userOffsetY = ((cy - tapOffset.y) * (targetScale - 1f)).coerceIn(-maxY, maxY)
                            }
                        },
                        onTap = { tapOffset ->
                            if (userScale > 1.08f) {
                                onCenterTap()
                                return@detectTapGestures
                            }
                            val fracX = tapOffset.x / size.width.coerceAtLeast(1)
                            when {
                                fracX < 0.26f -> if (isRtlNavigation) onNextTap() else onPrevTap()
                                fracX > 0.74f -> if (isRtlNavigation) onPrevTap() else onNextTap()
                                else -> onCenterTap()
                            }
                        }
                    )
                }
                .pointerInput(resetKey, guidedPanel) {
                    awaitEachGesture {
                        awaitFirstDown(requireUnconsumed = false)
                        do {
                            val event = awaitPointerEvent()
                            val zoomChange = event.calculateZoom()
                            val panChange = event.calculatePan()
                            val isMultiTouch = event.changes.count { it.pressed } >= 2

                            if (guidedPanel == null && (isMultiTouch || userScale > 1.03f)) {
                                val nextScale = (userScale * zoomChange).coerceIn(1f, 4f)
                                val maxX = size.width * (nextScale - 1f) * 0.5f
                                val maxY = size.height * (nextScale - 1f) * 0.5f
                                userScale = nextScale
                                if (nextScale <= 1.01f) {
                                    userOffsetX = 0f
                                    userOffsetY = 0f
                                } else {
                                    userOffsetX = (userOffsetX + panChange.x).coerceIn(-maxX, maxX)
                                    userOffsetY = (userOffsetY + panChange.y).coerceIn(-maxY, maxY)
                                }
                                event.changes.forEach { change ->
                                    if (change.positionChanged()) change.consume()
                                }
                            }
                        } while (event.changes.any { it.pressed })
                    }
                },
            contentAlignment = Alignment.Center
        ) {
            val viewW = constraints.maxWidth.toFloat().coerceAtLeast(1f)
            val viewH = constraints.maxHeight.toFloat().coerceAtLeast(1f)

            // Compute target transform for Guided Panel View vs manual zoom
            val targetScale: Float
            val targetTx: Float
            val targetTy: Float

            if (guidedPanel != null && bitmap != null) {
                val imgRatio = bitmap.width.toFloat() / bitmap.height.coerceAtLeast(1).toFloat()
                val viewRatio = viewW / viewH
                val fittedW = if (imgRatio > viewRatio) viewW else viewH * imgRatio
                val fittedH = if (imgRatio > viewRatio) viewW / imgRatio else viewH
                val panelW = (guidedPanel.width * fittedW).coerceAtLeast(60f)
                val panelH = (guidedPanel.height * fittedH).coerceAtLeast(60f)
                val s = minOf(viewW * 0.94f / panelW, viewH * 0.84f / panelH).coerceIn(1.0f, 2.75f)
                val dx = (0.5f - guidedPanel.centerX) * fittedW * s
                val dy = (0.5f - guidedPanel.centerY) * fittedH * s
                val maxDx = (fittedW * s - viewW).coerceAtLeast(0f) * 0.5f + viewW * 0.08f
                val maxDy = (fittedH * s - viewH).coerceAtLeast(0f) * 0.5f + viewH * 0.08f
                targetScale = s
                targetTx = dx.coerceIn(-maxDx, maxDx)
                targetTy = dy.coerceIn(-maxDy, maxDy)
            } else {
                targetScale = userScale
                targetTx = userOffsetX
                targetTy = userOffsetY
            }

            val animSpec = spring<Float>(
                dampingRatio = Spring.DampingRatioNoBouncy,
                stiffness = Spring.StiffnessMediumLow
            )
            val renderScale by animateFloatAsState(
                targetValue = targetScale,
                animationSpec = animSpec,
                label = "pageScale"
            )
            val renderTx by animateFloatAsState(
                targetValue = targetTx,
                animationSpec = animSpec,
                label = "pageTx"
            )
            val renderTy by animateFloatAsState(
                targetValue = targetTy,
                animationSpec = animSpec,
                label = "pageTy"
            )

            when {
                bitmap != null && !bitmap.isRecycled -> {
                    val fitModifier = when {
                        guidedPanel != null -> Modifier.fillMaxSize()
                        pageFitMode == PageFitMode.FIT_WIDTH -> Modifier.fillMaxWidth()
                        pageFitMode == PageFitMode.FIT_HEIGHT -> Modifier.fillMaxHeight()
                        else -> Modifier.fillMaxSize()
                    }
                    Box(
                        modifier = fitModifier.graphicsLayer {
                            scaleX = renderScale
                            scaleY = renderScale
                            translationX = renderTx
                            translationY = renderTy
                        },
                        contentAlignment = Alignment.Center
                    ) {
                        ComicPageArtwork(
                            bitmap = bitmap,
                            bubbles = bubbles,
                            dialogueLanguage = dialogueLanguage,
                            colorFilter = colorFilter,
                            highlightedPanel = guidedPanel
                        )
                    }
                }

                isLoading -> {
                    CircularProgressIndicator(
                        color = ComicAmber,
                        strokeWidth = 3.dp,
                        modifier = Modifier.size(38.dp)
                    )
                }

                else -> {
                    Text(
                        text = strings.pageLoadError,
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White.copy(alpha = 0.72f),
                        modifier = Modifier.border(
                            1.dp,
                            Color.White.copy(alpha = 0.2f),
                            RoundedCornerShape(10.dp)
                        ).padding(horizontal = 16.dp, vertical = 10.dp)
                    )
                }
            }
        }
    }
}
