package app.subflow.export

import android.graphics.Bitmap
import androidx.annotation.OptIn
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay

/**
 * The burn-in surface: one `BitmapOverlay` that asks the painter what the frame
 * should look like at this instant.
 *
 * Media3 re-uploads the GL texture whenever the returned bitmap's identity (or
 * generation id) changes, which is exactly the granularity the painter caches
 * at, so a caption that changes once per word uploads once per word instead of
 * once per frame.
 */
@OptIn(UnstableApi::class)
internal class CaptionOverlay(
    private val painter: CaptionFramePainter,
) : BitmapOverlay() {

    override fun getBitmap(presentationTimeUs: Long): Bitmap =
        painter.bitmapFor(presentationTimeUs)

    /**
     * Overridden because the base class reads the size of the *last* bitmap it
     * uploaded, which is null on the first frame.
     */
    override fun getTextureSize(presentationTimeUs: Long): Size {
        val bitmap = painter.bitmapFor(presentationTimeUs)
        return Size(bitmap.width, bitmap.height)
    }
}
