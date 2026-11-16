package com.qabak.comics.data.parser

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.util.LruCache
import androidx.documentfile.provider.DocumentFile
import com.github.junrar.Archive
import com.github.junrar.rarfile.FileHeader
import com.qabak.comics.model.BundledComicManifest
import com.qabak.comics.model.ComicInfoMetadata
import com.qabak.comics.model.ComicSourceType
import com.qabak.comics.model.DialogueBubble
import com.qabak.comics.model.PanelRect
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.io.File
import java.io.FileInputStream
import java.util.zip.ZipFile

class UnsupportedRar5Exception : Exception("RAR5 archives are not supported directly; please convert to CBZ/ZIP or PDF.")
class EmptyComicArchiveException : Exception("No readable comic pages were found in the selected file.")

/**
 * Memory-aware shared bitmap cache for smooth 60fps paging and thumbnail scrolling.
 */
object PageBitmapCache {
    private val maxCacheKb: Int = ((Runtime.getRuntime().maxMemory() / 1024L) / 6L)
        .toInt()
        .coerceIn(16 * 1024, 96 * 1024)

    private val cache = object : LruCache<String, Bitmap>(maxCacheKb) {
        override fun sizeOf(key: String, value: Bitmap): Int =
            (value.allocationByteCount / 1024).coerceAtLeast(1)
    }

    fun get(key: String): Bitmap? {
        val bmp = cache.get(key)
        return if (bmp != null && !bmp.isRecycled) bmp else null
    }

    fun put(key: String, bitmap: Bitmap) {
        if (!bitmap.isRecycled) {
            cache.put(key, bitmap)
        }
    }

    fun clear() {
        cache.evictAll()
    }
}

object BitmapDecodeHelper {
    fun decodeBytes(bytes: ByteArray, maxWidth: Int, maxHeight: Int): Bitmap? {
        if (bytes.isEmpty()) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        val options = BitmapFactory.Options().apply {
            inSampleSize = calculateInSampleSize(bounds.outWidth, bounds.outHeight, maxWidth, maxHeight)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
    }

    fun decodeFile(file: File, maxWidth: Int, maxHeight: Int): Bitmap? {
        if (!file.exists() || file.length() == 0L) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        val options = BitmapFactory.Options().apply {
            inSampleSize = calculateInSampleSize(bounds.outWidth, bounds.outHeight, maxWidth, maxHeight)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return BitmapFactory.decodeFile(file.absolutePath, options)
    }

    fun calculateInSampleSize(srcW: Int, srcH: Int, reqW: Int, reqH: Int): Int {
        var sample = 1
        val safeW = reqW.coerceAtLeast(120)
        val safeH = reqH.coerceAtLeast(160)
        if (srcH > safeH || srcW > safeW) {
            val halfH = srcH / 2
            val halfW = srcW / 2
            while ((halfH / sample) >= safeH && (halfW / sample) >= safeW) {
                sample *= 2
            }
        }
        // Extra safety ceiling so ultra-huge 8000px scans never exceed Android Canvas texture limits
        while (srcW / sample > 3600 || srcH / sample > 4800) {
            sample *= 2
        }
        return sample.coerceAtLeast(1)
    }
}

interface ComicPageSource : Closeable {
    val pageCount: Int
    val hasOverlayDialogue: Boolean get() = false

    fun peekCachedPage(pageIndex: Int, maxWidth: Int = 1440): Bitmap? = null
    suspend fun renderPage(pageIndex: Int, maxWidth: Int = 1440, maxHeight: Int = 2200): Bitmap?
    suspend fun getPanels(pageIndex: Int, rtlOrder: Boolean): List<PanelRect>
    fun getBubbles(pageIndex: Int): List<DialogueBubble> = emptyList()
    fun getPageTitle(pageIndex: Int, isFarsi: Boolean): String? = null
}

/**
 * Bundled comic source backed by `assets/comics/<id>/manifest.json` + high-res WebP pages.
 */
class BundledPageSource(
    private val context: Context,
    private val comicDirId: String
) : ComicPageSource {

    private val json = Json { ignoreUnknownKeys = true }

    val manifest: BundledComicManifest by lazy {
        val raw = context.assets.open("comics/$comicDirId/manifest.json")
            .bufferedReader(Charsets.UTF_8)
            .use { it.readText() }
        json.decodeFromString(BundledComicManifest.serializer(), raw)
    }

    override val pageCount: Int
        get() = manifest.pages.size

    override val hasOverlayDialogue: Boolean
        get() = manifest.pages.any { it.bubbles.isNotEmpty() }

    override fun peekCachedPage(pageIndex: Int, maxWidth: Int): Bitmap? {
        val bucket = if (maxWidth <= 480) "thumb" else "full"
        return PageBitmapCache.get("bundled:$comicDirId:$pageIndex:$bucket")
    }

    override suspend fun renderPage(pageIndex: Int, maxWidth: Int, maxHeight: Int): Bitmap? =
        withContext(Dispatchers.IO) {
            val page = manifest.pages.getOrNull(pageIndex) ?: return@withContext null
            val bucket = if (maxWidth <= 480) "thumb" else "full"
            val cacheKey = "bundled:$comicDirId:$pageIndex:$bucket"
            PageBitmapCache.get(cacheKey)?.let { return@withContext it }

            val bytes = runCatching {
                context.assets.open("comics/$comicDirId/${page.file}").use { it.readBytes() }
            }.getOrNull() ?: return@withContext null

            BitmapDecodeHelper.decodeBytes(bytes, maxWidth, maxHeight)?.also {
                PageBitmapCache.put(cacheKey, it)
            }
        }

    override suspend fun getPanels(pageIndex: Int, rtlOrder: Boolean): List<PanelRect> {
        val meta = manifest.pages.getOrNull(pageIndex) ?: return listOf(PanelRect(0f, 0f, 1f, 1f))
        val base = meta.panels.ifEmpty { listOf(PanelRect(0f, 0f, 1f, 1f)) }
        if (!rtlOrder || base.size <= 1) return base
        // Re-order side-by-side panels within the same horizontal band right-to-left
        return sortPanelsByReadingOrder(base, rtl = true)
    }

    override fun getBubbles(pageIndex: Int): List<DialogueBubble> =
        manifest.pages.getOrNull(pageIndex)?.bubbles.orEmpty()

    override fun getPageTitle(pageIndex: Int, isFarsi: Boolean): String? {
        val p = manifest.pages.getOrNull(pageIndex) ?: return null
        return if (isFarsi) p.titleFa.ifBlank { null } else p.titleEn.ifBlank { null }
    }

    override fun close() = Unit
}

/**
 * CBZ / ZIP comic archive reader with natural sorting and embedded `ComicInfo.xml` extraction.
 */
class CbzPageSource(private val archiveFile: File) : ComicPageSource {

    private val mutex = Mutex()
    private var zipFile: ZipFile? = null
    private val pageEntries: List<String>

    init {
        val zf = ZipFile(archiveFile)
        zipFile = zf
        val names = mutableListOf<String>()
        val entries = zf.entries()
        while (entries.hasMoreElements()) {
            val entry = entries.nextElement()
            if (!entry.isDirectory && NaturalOrderComparator.isSupportedImageEntry(entry.name)) {
                names.add(entry.name)
            }
        }
        names.sortWith(NaturalOrderComparator)
        pageEntries = names
    }

    override val pageCount: Int get() = pageEntries.size

    fun readComicInfo(): ComicInfoMetadata? {
        val zf = zipFile ?: return null
        val entries = zf.entries()
        while (entries.hasMoreElements()) {
            val entry = entries.nextElement()
            val leaf = entry.name.replace('\\', '/').substringAfterLast('/')
            if (!entry.isDirectory && leaf.equals("ComicInfo.xml", ignoreCase = true)) {
                return zf.getInputStream(entry).use { ComicInfoXmlParser.parse(it) }
            }
        }
        return null
    }

    override suspend fun renderPage(pageIndex: Int, maxWidth: Int, maxHeight: Int): Bitmap? =
        withContext(Dispatchers.IO) {
            val entryName = pageEntries.getOrNull(pageIndex) ?: return@withContext null
            val bucket = if (maxWidth <= 480) "thumb" else "full"
            val cacheKey = "cbz:${archiveFile.absolutePath}:$pageIndex:$bucket"
            PageBitmapCache.get(cacheKey)?.let { return@withContext it }

            val bytes = mutex.withLock {
                val zf = zipFile ?: return@withLock null
                val entry = zf.getEntry(entryName) ?: return@withLock null
                runCatching { zf.getInputStream(entry).use { it.readBytes() } }.getOrNull()
            } ?: return@withContext null

            BitmapDecodeHelper.decodeBytes(bytes, maxWidth, maxHeight)?.also {
                PageBitmapCache.put(cacheKey, it)
            }
        }

    override suspend fun getPanels(pageIndex: Int, rtlOrder: Boolean): List<PanelRect> =
        withContext(Dispatchers.Default) {
            val bmp = renderPage(pageIndex, maxWidth = 720, maxHeight = 1080)
                ?: return@withContext listOf(PanelRect(0f, 0f, 1f, 1f))
            PanelDetector.detectPanels(bmp, rtlOrder)
        }

    override fun close() {
        runCatching { zipFile?.close() }
        zipFile = null
    }
}

/**
 * CBR / RAR comic archive reader backed by Junrar with upfront RAR5 signature detection.
 */
class CbrPageSource(private val archiveFile: File) : ComicPageSource {

    private val mutex = Mutex()
    private var archive: Archive? = null
    private val headers: List<FileHeader>

    init {
        if (isRar5Archive(archiveFile)) {
            throw UnsupportedRar5Exception()
        }
        val arc = Archive(archiveFile)
        archive = arc
        headers = arc.fileHeaders
            .filter { !it.isDirectory && NaturalOrderComparator.isSupportedImageEntry(it.fileName) }
            .sortedWith { a, b -> NaturalOrderComparator.compare(a.fileName, b.fileName) }
    }

    override val pageCount: Int get() = headers.size

    fun readComicInfo(): ComicInfoMetadata? {
        val arc = archive ?: return null
        val infoHeader = arc.fileHeaders.firstOrNull { header ->
            !header.isDirectory &&
                header.fileName.replace('\\', '/').substringAfterLast('/')
                    .equals("ComicInfo.xml", ignoreCase = true)
        } ?: return null
        return runCatching {
            val baos = ByteArrayOutputStream()
            arc.extractFile(infoHeader, baos)
            ComicInfoXmlParser.parse(ByteArrayInputStream(baos.toByteArray()))
        }.getOrNull()
    }

    override suspend fun renderPage(pageIndex: Int, maxWidth: Int, maxHeight: Int): Bitmap? =
        withContext(Dispatchers.IO) {
            val header = headers.getOrNull(pageIndex) ?: return@withContext null
            val bucket = if (maxWidth <= 480) "thumb" else "full"
            val cacheKey = "cbr:${archiveFile.absolutePath}:$pageIndex:$bucket"
            PageBitmapCache.get(cacheKey)?.let { return@withContext it }

            val bytes = mutex.withLock {
                val arc = archive ?: return@withLock null
                runCatching {
                    val out = ByteArrayOutputStream()
                    arc.extractFile(header, out)
                    out.toByteArray()
                }.getOrNull()
            } ?: return@withContext null

            BitmapDecodeHelper.decodeBytes(bytes, maxWidth, maxHeight)?.also {
                PageBitmapCache.put(cacheKey, it)
            }
        }

    override suspend fun getPanels(pageIndex: Int, rtlOrder: Boolean): List<PanelRect> =
        withContext(Dispatchers.Default) {
            val bmp = renderPage(pageIndex, maxWidth = 720, maxHeight = 1080)
                ?: return@withContext listOf(PanelRect(0f, 0f, 1f, 1f))
            PanelDetector.detectPanels(bmp, rtlOrder)
        }

    override fun close() {
        runCatching { archive?.close() }
        archive = null
    }

    companion object {
        private val RAR5_MAGIC = byteArrayOf(0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00)

        fun isRar5Archive(file: File): Boolean {
            if (!file.exists() || file.length() < 8L) return false
            val head = ByteArray(8)
            val read = runCatching { FileInputStream(file).use { it.read(head) } }.getOrDefault(0)
            return read == 8 && head.contentEquals(RAR5_MAGIC)
        }
    }
}

/**
 * Native hardware-fast Android `PdfRenderer` source with coroutine-safe sequential page access.
 */
class PdfPageSource(private val pdfFile: File) : ComicPageSource {

    private val mutex = Mutex()
    private var pfd: ParcelFileDescriptor? =
        ParcelFileDescriptor.open(pdfFile, ParcelFileDescriptor.MODE_READ_ONLY)
    private var renderer: PdfRenderer? = pfd?.let { PdfRenderer(it) }

    override val pageCount: Int
        get() = renderer?.pageCount ?: 0

    override suspend fun renderPage(pageIndex: Int, maxWidth: Int, maxHeight: Int): Bitmap? =
        withContext(Dispatchers.IO) {
            val bucket = if (maxWidth <= 480) "thumb" else "full"
            val cacheKey = "pdf:${pdfFile.absolutePath}:$pageIndex:$bucket"
            PageBitmapCache.get(cacheKey)?.let { return@withContext it }

            mutex.withLock {
                val pdf = renderer ?: return@withLock null
                if (pageIndex !in 0 until pdf.pageCount) return@withLock null
                runCatching {
                    pdf.openPage(pageIndex).use { page ->
                        val pw = page.width.coerceAtLeast(1)
                        val ph = page.height.coerceAtLeast(1)
                        val scaleW = maxWidth.coerceIn(240, 2200).toFloat() / pw
                        val scaleH = maxHeight.coerceIn(320, 3200).toFloat() / ph
                        val scale = minOf(scaleW, scaleH).coerceIn(0.25f, 3.5f)
                        val targetW = (pw * scale).toInt().coerceAtLeast(1)
                        val targetH = (ph * scale).toInt().coerceAtLeast(1)

                        val bitmap = Bitmap.createBitmap(targetW, targetH, Bitmap.Config.ARGB_8888)
                        // Fill crisp white paper backdrop before rendering transparent PDF content
                        Canvas(bitmap).drawColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        PageBitmapCache.put(cacheKey, bitmap)
                        bitmap
                    }
                }.getOrNull()
            }
        }

    override suspend fun getPanels(pageIndex: Int, rtlOrder: Boolean): List<PanelRect> =
        withContext(Dispatchers.Default) {
            val bmp = renderPage(pageIndex, maxWidth = 720, maxHeight = 1080)
                ?: return@withContext listOf(PanelRect(0f, 0f, 1f, 1f))
            PanelDetector.detectPanels(bmp, rtlOrder)
        }

    override fun close() {
        runCatching { renderer?.close() }
        runCatching { pfd?.close() }
        renderer = null
        pfd = null
    }
}

/**
 * Local directory of image pages (imported multi-image comic or copied image folder).
 */
class LocalImageDirPageSource(private val directory: File) : ComicPageSource {

    private val imageFiles: List<File> = directory.listFiles()
        ?.filter { it.isFile && NaturalOrderComparator.isSupportedImageEntry(it.name) }
        ?.sortedWith { a, b -> NaturalOrderComparator.compare(a.name, b.name) }
        .orEmpty()

    override val pageCount: Int get() = imageFiles.size

    override suspend fun renderPage(pageIndex: Int, maxWidth: Int, maxHeight: Int): Bitmap? =
        withContext(Dispatchers.IO) {
            val file = imageFiles.getOrNull(pageIndex) ?: return@withContext null
            val bucket = if (maxWidth <= 480) "thumb" else "full"
            val cacheKey = "imgdir:${file.absolutePath}:$bucket"
            PageBitmapCache.get(cacheKey)?.let { return@withContext it }

            BitmapDecodeHelper.decodeFile(file, maxWidth, maxHeight)?.also {
                PageBitmapCache.put(cacheKey, it)
            }
        }

    override suspend fun getPanels(pageIndex: Int, rtlOrder: Boolean): List<PanelRect> =
        withContext(Dispatchers.Default) {
            val bmp = renderPage(pageIndex, maxWidth = 720, maxHeight = 1080)
                ?: return@withContext listOf(PanelRect(0f, 0f, 1f, 1f))
            PanelDetector.detectPanels(bmp, rtlOrder)
        }

    override fun close() = Unit
}

/**
 * Direct Storage Access Framework (SAF) folder reader when persisted URI access is used.
 */
class SafFolderPageSource(
    private val context: Context,
    treeUriString: String
) : ComicPageSource {

    private val imageUris: List<Uri> = run {
        val treeUri = Uri.parse(treeUriString)
        val root = DocumentFile.fromTreeUri(context, treeUri)
        root?.listFiles()
            ?.filter { doc ->
                doc.isFile && doc.name?.let { NaturalOrderComparator.isSupportedImageEntry(it) } == true
            }
            ?.sortedWith { a, b -> NaturalOrderComparator.compare(a.name.orEmpty(), b.name.orEmpty()) }
            ?.map { it.uri }
            .orEmpty()
    }

    override val pageCount: Int get() = imageUris.size

    override suspend fun renderPage(pageIndex: Int, maxWidth: Int, maxHeight: Int): Bitmap? =
        withContext(Dispatchers.IO) {
            val uri = imageUris.getOrNull(pageIndex) ?: return@withContext null
            val bucket = if (maxWidth <= 480) "thumb" else "full"
            val cacheKey = "saf:$uri:$bucket"
            PageBitmapCache.get(cacheKey)?.let { return@withContext it }

            val bytes = runCatching {
                context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            }.getOrNull() ?: return@withContext null

            BitmapDecodeHelper.decodeBytes(bytes, maxWidth, maxHeight)?.also {
                PageBitmapCache.put(cacheKey, it)
            }
        }

    override suspend fun getPanels(pageIndex: Int, rtlOrder: Boolean): List<PanelRect> =
        withContext(Dispatchers.Default) {
            val bmp = renderPage(pageIndex, maxWidth = 720, maxHeight = 1080)
                ?: return@withContext listOf(PanelRect(0f, 0f, 1f, 1f))
            PanelDetector.detectPanels(bmp, rtlOrder)
        }

    override fun close() = Unit
}

fun openComicPageSource(
    context: Context,
    sourceType: ComicSourceType,
    sourcePath: String
): ComicPageSource {
    return when (sourceType) {
        ComicSourceType.BUNDLED -> BundledPageSource(context, sourcePath)
        ComicSourceType.CBZ -> CbzPageSource(File(sourcePath))
        ComicSourceType.CBR -> CbrPageSource(File(sourcePath))
        ComicSourceType.PDF -> PdfPageSource(File(sourcePath))
        ComicSourceType.IMAGES -> LocalImageDirPageSource(File(sourcePath))
        ComicSourceType.FOLDER -> {
            if (sourcePath.startsWith("content://")) {
                SafFolderPageSource(context, sourcePath)
            } else {
                LocalImageDirPageSource(File(sourcePath))
            }
        }
    }
}

private fun sortPanelsByReadingOrder(panels: List<PanelRect>, rtl: Boolean): List<PanelRect> {
    if (panels.size <= 1) return panels
    val sortedByTop = panels.sortedBy { it.top }
    val rows = mutableListOf<MutableList<PanelRect>>()
    for (p in sortedByTop) {
        val lastRow = rows.lastOrNull()
        if (lastRow != null && kotlin.math.abs(lastRow.first().centerY - p.centerY) < 0.14f) {
            lastRow.add(p)
        } else {
            rows.add(mutableListOf(p))
        }
    }
    return rows.flatMap { row ->
        if (rtl) row.sortedByDescending { it.centerX } else row.sortedBy { it.centerX }
    }
}
