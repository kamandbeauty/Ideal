package com.qabak.comics.data.repository

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import androidx.documentfile.provider.DocumentFile
import com.qabak.comics.data.local.BookmarkDao
import com.qabak.comics.data.local.BookmarkEntity
import com.qabak.comics.data.local.ComicDao
import com.qabak.comics.data.local.ComicEntity
import com.qabak.comics.data.local.PreferencesRepository
import com.qabak.comics.data.parser.BitmapDecodeHelper
import com.qabak.comics.data.parser.CbrPageSource
import com.qabak.comics.data.parser.CbzPageSource
import com.qabak.comics.data.parser.ComicPageSource
import com.qabak.comics.data.parser.EmptyComicArchiveException
import com.qabak.comics.data.parser.PageBitmapCache
import com.qabak.comics.data.parser.openComicPageSource
import com.qabak.comics.model.BookmarkItem
import com.qabak.comics.model.BundledCatalog
import com.qabak.comics.model.BundledComicManifest
import com.qabak.comics.model.ComicBook
import com.qabak.comics.model.ComicInfoMetadata
import com.qabak.comics.model.ComicSourceType
import com.qabak.comics.model.ReadingMode
import com.qabak.comics.model.ReadingStats
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class ComicRepository(
    private val context: Context,
    private val comicDao: ComicDao,
    private val bookmarkDao: BookmarkDao,
    val preferences: PreferencesRepository
) {
    private val appContext = context.applicationContext
    private val json = Json { ignoreUnknownKeys = true }

    private val importedDir: File
        get() = File(appContext.filesDir, "imported").apply { mkdirs() }

    private val coversDir: File
        get() = File(appContext.filesDir, "covers").apply { mkdirs() }

    private val sharedDir: File
        get() = File(appContext.cacheDir, "shared").apply { mkdirs() }

    val comicsFlow: Flow<List<ComicBook>> = comicDao.observeAllComics()
        .map { list -> list.map { it.toDomain() } }

    val allBookmarksFlow: Flow<List<BookmarkItem>> = bookmarkDao.observeAllBookmarks()
        .map { list -> list.map { it.toDomain() } }

    val readingStatsFlow: Flow<ReadingStats> = combine(comicsFlow, allBookmarksFlow) { comics, bookmarks ->
        ReadingStats(
            totalComics = comics.size,
            completedComics = comics.count { it.isCompleted },
            inProgressComics = comics.count { it.isStarted && !it.isCompleted },
            totalPagesRead = comics.sumOf { comic ->
                when {
                    comic.isCompleted -> comic.pageCount
                    comic.isStarted -> (comic.currentPage + 1).coerceAtMost(comic.pageCount)
                    else -> 0
                }
            },
            totalBookmarks = bookmarks.size
        )
    }

    fun observeComic(comicId: String): Flow<ComicBook?> =
        comicDao.observeComicById(comicId).map { it?.toDomain() }

    fun observeBookmarksForComic(comicId: String): Flow<List<BookmarkItem>> =
        bookmarkDao.observeBookmarksForComic(comicId).map { list -> list.map { it.toDomain() } }

    suspend fun getComicOnce(comicId: String): ComicBook? =
        comicDao.getComicById(comicId)?.toDomain()

    fun openSource(comic: ComicBook): ComicPageSource =
        openComicPageSource(appContext, comic.sourceType, comic.sourcePath)

    suspend fun ensureBundledComicsSeeded() = withContext(Dispatchers.IO) {
        val currentSettings = preferences.settingsFlow.first()
        val catalog = loadBundledCatalog() ?: return@withContext
        if (currentSettings.seededVersion >= catalog.version && comicDao.getAllComicsOnce().isNotEmpty()) {
            return@withContext
        }
        seedFromCatalog(catalog)
        preferences.setSeededVersion(catalog.version)
    }

    suspend fun restoreBundledComics(): Int = withContext(Dispatchers.IO) {
        val catalog = loadBundledCatalog() ?: return@withContext 0
        seedFromCatalog(catalog)
    }

    private suspend fun seedFromCatalog(catalog: BundledCatalog): Int {
        var added = 0
        val baseTime = System.currentTimeMillis()
        catalog.comics.forEachIndexed { index, comicDirId ->
            val entityId = "bundled_$comicDirId"
            if (comicDao.getComicById(entityId) == null) {
                val manifest = runCatching {
                    val raw = appContext.assets.open("comics/$comicDirId/manifest.json")
                        .bufferedReader(Charsets.UTF_8)
                        .use { it.readText() }
                    json.decodeFromString(BundledComicManifest.serializer(), raw)
                }.getOrNull() ?: return@forEachIndexed

                val firstPage = manifest.pages.firstOrNull()?.file ?: "page_00.webp"
                val entity = ComicEntity(
                    id = entityId,
                    titleFa = manifest.titleFa,
                    titleEn = manifest.titleEn,
                    seriesFa = manifest.seriesFa,
                    seriesEn = manifest.seriesEn,
                    authorFa = manifest.authorFa,
                    authorEn = manifest.authorEn,
                    genreFa = manifest.genreFa,
                    genreEn = manifest.genreEn,
                    descriptionFa = manifest.descriptionFa,
                    descriptionEn = manifest.descriptionEn,
                    sourceType = ComicSourceType.BUNDLED.name,
                    sourcePath = comicDirId,
                    coverPath = "asset://comics/$comicDirId/$firstPage",
                    accentHex = manifest.accentHex,
                    pageCount = manifest.pages.size,
                    currentPage = 0,
                    isFavorite = index == 0,
                    isCompleted = false,
                    preferredMode = manifest.defaultMode,
                    addedAt = baseTime - index * 1000L,
                    lastReadAt = 0L
                )
                comicDao.insertComicIfAbsent(entity)
                added++
            }
        }
        return added
    }

    private fun loadBundledCatalog(): BundledCatalog? = runCatching {
        val raw = appContext.assets.open("comics/catalog.json")
            .bufferedReader(Charsets.UTF_8)
            .use { it.readText() }
        json.decodeFromString(BundledCatalog.serializer(), raw)
    }.getOrNull()

    suspend fun loadCoverBitmap(coverPath: String, maxWidth: Int = 480, maxHeight: Int = 720): Bitmap? =
        withContext(Dispatchers.IO) {
            if (coverPath.isBlank()) return@withContext null
            val cacheKey = "cover:$coverPath:$maxWidth"
            PageBitmapCache.get(cacheKey)?.let { return@withContext it }

            val bitmap = if (coverPath.startsWith("asset://")) {
                val assetRel = coverPath.removePrefix("asset://")
                val bytes = runCatching {
                    appContext.assets.open(assetRel).use { it.readBytes() }
                }.getOrNull() ?: return@withContext null
                BitmapDecodeHelper.decodeBytes(bytes, maxWidth, maxHeight)
            } else {
                BitmapDecodeHelper.decodeFile(File(coverPath), maxWidth, maxHeight)
            }
            bitmap?.also { PageBitmapCache.put(cacheKey, it) }
        }

    suspend fun loadBookmarkThumbnail(item: BookmarkItem): Bitmap? = withContext(Dispatchers.IO) {
        val cacheKey = "bmthumb:${item.comicId}:${item.pageIndex}"
        PageBitmapCache.get(cacheKey)?.let { return@withContext it }
        runCatching {
            openComicPageSource(appContext, item.comicSourceType, item.comicSourcePath).use { src ->
                src.renderPage(item.pageIndex, maxWidth = 320, maxHeight = 480)
            }
        }.getOrNull()?.also { PageBitmapCache.put(cacheKey, it) }
    }

    /**
     * Imports a CBZ, ZIP, CBR, RAR, PDF, or single image file from an Android Content URI.
     */
    suspend fun importComicFile(uri: Uri, defaultMode: ReadingMode): Result<ComicBook> =
        withContext(Dispatchers.IO) {
            runCatching {
                val displayName = resolveDisplayName(uri) ?: "Comic_${System.currentTimeMillis()}"
                val cleanBaseTitle = prettifyFileTitle(displayName)
                val id = "imp_${UUID.randomUUID().toString().take(12)}"
                val tempFile = File(importedDir, "$id.tmp")

                val input = appContext.contentResolver.openInputStream(uri)
                    ?: error("Cannot open selected file.")
                input.use { ins ->
                    FileOutputStream(tempFile).use { outs -> ins.copyTo(outs, bufferSize = 64 * 1024) }
                }

                if (!tempFile.exists() || tempFile.length() == 0L) {
                    tempFile.delete()
                    throw EmptyComicArchiveException()
                }

                val detectedType = detectFileSourceType(tempFile, displayName)
                when (detectedType) {
                    ComicSourceType.IMAGES -> {
                        val imgDir = File(importedDir, id).apply { mkdirs() }
                        val ext = displayName.substringAfterLast('.', "jpg").lowercase()
                        val targetImg = File(imgDir, "page_0001.$ext")
                        tempFile.renameTo(targetImg)
                        finalizeImportedComic(
                            id = id,
                            fallbackTitle = cleanBaseTitle,
                            sourceType = ComicSourceType.IMAGES,
                            sourcePath = imgDir.absolutePath,
                            defaultMode = defaultMode,
                            cleanupOnFail = imgDir
                        )
                    }

                    else -> {
                        val ext = when (detectedType) {
                            ComicSourceType.PDF -> "pdf"
                            ComicSourceType.CBR -> "cbr"
                            else -> "cbz"
                        }
                        val finalFile = File(importedDir, "$id.$ext")
                        tempFile.renameTo(finalFile)
                        finalizeImportedComic(
                            id = id,
                            fallbackTitle = cleanBaseTitle,
                            sourceType = detectedType,
                            sourcePath = finalFile.absolutePath,
                            defaultMode = defaultMode,
                            cleanupOnFail = finalFile
                        )
                    }
                }
            }
        }

    /**
     * Combines multiple selected images into a single comic book in the user's library.
     */
    suspend fun importImageCollection(
        uris: List<Uri>,
        customTitle: String?,
        defaultMode: ReadingMode
    ): Result<ComicBook> = withContext(Dispatchers.IO) {
        runCatching {
            if (uris.isEmpty()) throw EmptyComicArchiveException()
            val id = "imgs_${UUID.randomUUID().toString().take(12)}"
            val targetDir = File(importedDir, id).apply { mkdirs() }

            var written = 0
            uris.forEachIndexed { idx, uri ->
                val name = resolveDisplayName(uri).orEmpty()
                val ext = name.substringAfterLast('.', "jpg")
                    .lowercase()
                    .takeIf { it in setOf("jpg", "jpeg", "png", "webp", "bmp", "gif") } ?: "jpg"
                val dest = File(targetDir, "page_%04d_%s.%s".format(idx + 1, idx, ext))
                appContext.contentResolver.openInputStream(uri)?.use { ins ->
                    FileOutputStream(dest).use { outs -> ins.copyTo(outs, bufferSize = 32 * 1024) }
                    if (dest.length() > 0L) written++
                }
            }
            if (written == 0) {
                targetDir.deleteRecursively()
                throw EmptyComicArchiveException()
            }

            val title = customTitle?.trim()?.takeIf { it.isNotEmpty() }
                ?: resolveDisplayName(uris.first())?.let { prettifyFileTitle(it) }
                ?: "My Comic"

            finalizeImportedComic(
                id = id,
                fallbackTitle = title,
                sourceType = ComicSourceType.IMAGES,
                sourcePath = targetDir.absolutePath,
                defaultMode = defaultMode,
                cleanupOnFail = targetDir
            )
        }
    }

    /**
     * Imports a folder of comic images via Storage Access Framework (`OpenDocumentTree`).
     */
    suspend fun importImageFolder(treeUri: Uri, defaultMode: ReadingMode): Result<ComicBook> =
        withContext(Dispatchers.IO) {
            runCatching {
                runCatching {
                    appContext.contentResolver.takePersistableUriPermission(
                        treeUri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                }
                val docTree = DocumentFile.fromTreeUri(appContext, treeUri)
                val folderTitle = docTree?.name?.let { prettifyFileTitle(it) }?.ifBlank { null }
                    ?: "Comic Folder"
                val id = "dir_${UUID.randomUUID().toString().take(12)}"

                finalizeImportedComic(
                    id = id,
                    fallbackTitle = folderTitle,
                    sourceType = ComicSourceType.FOLDER,
                    sourcePath = treeUri.toString(),
                    defaultMode = defaultMode,
                    cleanupOnFail = null
                )
            }
        }

    private suspend fun finalizeImportedComic(
        id: String,
        fallbackTitle: String,
        sourceType: ComicSourceType,
        sourcePath: String,
        defaultMode: ReadingMode,
        cleanupOnFail: File?
    ): ComicBook {
        try {
            openComicPageSource(appContext, sourceType, sourcePath).use { source ->
                if (source.pageCount <= 0) {
                    throw EmptyComicArchiveException()
                }
                val meta: ComicInfoMetadata? = when (source) {
                    is CbzPageSource -> source.readComicInfo()
                    is CbrPageSource -> source.readComicInfo()
                    else -> null
                }

                val coverBmp = source.renderPage(0, maxWidth = 540, maxHeight = 810)
                val coverFile = File(coversDir, "$id.webp")
                var accent = "#FFB703"
                if (coverBmp != null) {
                    accent = extractAccentHex(coverBmp)
                    saveBitmapAsWebp(coverBmp, coverFile)
                }

                val resolvedTitle = meta?.title?.takeIf { it.isNotBlank() } ?: fallbackTitle
                val resolvedSeries = buildString {
                    if (!meta?.series.isNullOrBlank()) {
                        append(meta?.series)
                        if (!meta?.number.isNullOrBlank()) append(" #${meta?.number}")
                    }
                }
                val resolvedAuthor = meta?.writer.orEmpty()
                val resolvedGenreFa = meta?.genre?.takeIf { it.isNotBlank() } ?: when (sourceType) {
                    ComicSourceType.PDF -> "کتاب PDF"
                    ComicSourceType.CBZ, ComicSourceType.CBR -> "آرشیو کمیک"
                    ComicSourceType.IMAGES, ComicSourceType.FOLDER -> "مجموعه تصویری"
                    ComicSourceType.BUNDLED -> "اختصاصی"
                }
                val resolvedGenreEn = meta?.genre?.takeIf { it.isNotBlank() } ?: when (sourceType) {
                    ComicSourceType.PDF -> "PDF Comic"
                    ComicSourceType.CBZ, ComicSourceType.CBR -> "Comic Archive"
                    ComicSourceType.IMAGES, ComicSourceType.FOLDER -> "Image Collection"
                    ComicSourceType.BUNDLED -> "Original"
                }
                val resolvedMode = if (meta?.isMangaRtl == true) ReadingMode.PAGED_RTL else defaultMode

                val now = System.currentTimeMillis()
                val entity = ComicEntity(
                    id = id,
                    titleFa = resolvedTitle,
                    titleEn = resolvedTitle,
                    seriesFa = resolvedSeries,
                    seriesEn = resolvedSeries,
                    authorFa = resolvedAuthor,
                    authorEn = resolvedAuthor,
                    genreFa = resolvedGenreFa,
                    genreEn = resolvedGenreEn,
                    descriptionFa = meta?.summary.orEmpty(),
                    descriptionEn = meta?.summary.orEmpty(),
                    sourceType = sourceType.name,
                    sourcePath = sourcePath,
                    coverPath = if (coverFile.exists()) coverFile.absolutePath else "",
                    accentHex = accent,
                    pageCount = source.pageCount,
                    currentPage = 0,
                    isFavorite = false,
                    isCompleted = false,
                    preferredMode = resolvedMode.name,
                    addedAt = now,
                    lastReadAt = 0L
                )
                comicDao.upsertComic(entity)
                return entity.toDomain()
            }
        } catch (t: Throwable) {
            cleanupOnFail?.deleteRecursively()
            throw t
        }
    }

    suspend fun updateReadingProgress(comicId: String, pageIndex: Int) {
        val current = comicDao.getComicById(comicId) ?: return
        val clamped = pageIndex.coerceIn(0, (current.pageCount - 1).coerceAtLeast(0))
        val reachedEnd = current.pageCount > 0 && clamped >= current.pageCount - 1
        comicDao.updateProgress(
            id = comicId,
            page = clamped,
            timestamp = System.currentTimeMillis(),
            completed = current.isCompleted || reachedEnd
        )
    }

    suspend fun toggleFavorite(comicId: String) {
        val current = comicDao.getComicById(comicId) ?: return
        comicDao.updateFavorite(comicId, !current.isFavorite)
    }

    suspend fun toggleCompleted(comicId: String) {
        val current = comicDao.getComicById(comicId) ?: return
        val nextCompleted = !current.isCompleted
        val targetPage = if (nextCompleted) (current.pageCount - 1).coerceAtLeast(0) else 0
        comicDao.updateCompleted(
            id = comicId,
            completed = nextCompleted,
            page = targetPage,
            timestamp = if (nextCompleted) System.currentTimeMillis() else 0L
        )
    }

    suspend fun setPreferredMode(comicId: String, mode: ReadingMode) {
        comicDao.updatePreferredMode(comicId, mode.name)
    }

    suspend fun deleteComic(comic: ComicBook) = withContext(Dispatchers.IO) {
        comicDao.deleteComic(comic.id)
        if (comic.sourceType != ComicSourceType.BUNDLED && !comic.sourcePath.startsWith("content://")) {
            runCatching { File(comic.sourcePath).deleteRecursively() }
        }
        if (comic.coverPath.isNotBlank() && !comic.coverPath.startsWith("asset://")) {
            runCatching { File(comic.coverPath).delete() }
        }
    }

    suspend fun toggleBookmark(comicId: String, pageIndex: Int, note: String = ""): Boolean {
        val existing = bookmarkDao.getBookmark(comicId, pageIndex)
        return if (existing != null) {
            bookmarkDao.deleteBookmarkAt(comicId, pageIndex)
            false
        } else {
            bookmarkDao.upsertBookmark(
                BookmarkEntity(
                    comicId = comicId,
                    pageIndex = pageIndex,
                    note = note.trim(),
                    createdAt = System.currentTimeMillis()
                )
            )
            true
        }
    }

    suspend fun saveBookmarkWithNote(comicId: String, pageIndex: Int, note: String) {
        val existing = bookmarkDao.getBookmark(comicId, pageIndex)
        if (existing != null) {
            bookmarkDao.updateNote(existing.id, note.trim())
        } else {
            bookmarkDao.upsertBookmark(
                BookmarkEntity(
                    comicId = comicId,
                    pageIndex = pageIndex,
                    note = note.trim(),
                    createdAt = System.currentTimeMillis()
                )
            )
        }
    }

    suspend fun deleteBookmark(bookmarkId: Long) {
        bookmarkDao.deleteBookmarkById(bookmarkId)
    }

    /**
     * Exports any comic in the library as a standard `.cbz` archive (with `ComicInfo.xml`) for sharing.
     */
    suspend fun exportComicAsCbz(comic: ComicBook): Result<File> = withContext(Dispatchers.IO) {
        runCatching {
            val safeName = comic.titleEn.ifBlank { comic.titleFa }
                .replace(Regex("[^A-Za-z0-9\\u0600-\\u06FF _-]"), "")
                .trim()
                .replace(' ', '_')
                .take(40)
                .ifBlank { "qabak_comic" }

            // If it is already a local CBZ file, copy cleanly into share directory
            if (comic.sourceType == ComicSourceType.CBZ) {
                val srcFile = File(comic.sourcePath)
                if (srcFile.exists()) {
                    val out = File(sharedDir, "$safeName.cbz")
                    srcFile.copyTo(out, overwrite = true)
                    return@runCatching out
                }
            }

            val outFile = File(sharedDir, "$safeName.cbz")
            openSource(comic).use { source ->
                ZipOutputStream(FileOutputStream(outFile)).use { zos ->
                    // Include ComicInfo.xml metadata
                    val xml = buildComicInfoXml(comic)
                    zos.putNextEntry(ZipEntry("ComicInfo.xml"))
                    zos.write(xml.toByteArray(Charsets.UTF_8))
                    zos.closeEntry()

                    for (i in 0 until source.pageCount) {
                        val bmp = source.renderPage(i, maxWidth = 1200, maxHeight = 1800) ?: continue
                        zos.putNextEntry(ZipEntry("page_%03d.jpg".format(i + 1)))
                        bmp.compress(Bitmap.CompressFormat.JPEG, 88, zos)
                        zos.closeEntry()
                    }
                }
            }
            outFile
        }
    }

    suspend fun calculateStorageBytes(): Long = withContext(Dispatchers.IO) {
        dirSize(importedDir) + dirSize(coversDir) + dirSize(sharedDir)
    }

    suspend fun clearTemporaryCache() = withContext(Dispatchers.IO) {
        PageBitmapCache.clear()
        runCatching { sharedDir.deleteRecursively(); sharedDir.mkdirs() }
    }

    private fun dirSize(dir: File): Long {
        if (!dir.exists()) return 0L
        return dir.walkTopDown().filter { it.isFile }.sumOf { it.length() }
    }

    private fun detectFileSourceType(file: File, fileName: String): ComicSourceType {
        val header = ByteArray(8)
        val read = runCatching { FileInputStream(file).use { it.read(header) } }.getOrDefault(0)
        if (read >= 4) {
            // %PDF
            if (header[0] == 0x25.toByte() && header[1] == 0x50.toByte() &&
                header[2] == 0x44.toByte() && header[3] == 0x46.toByte()
            ) return ComicSourceType.PDF
            // PK.. (ZIP / CBZ)
            if (header[0] == 0x50.toByte() && header[1] == 0x4B.toByte()) {
                return ComicSourceType.CBZ
            }
            // Rar! (RAR4 / RAR5 / CBR)
            if (header[0] == 0x52.toByte() && header[1] == 0x61.toByte() &&
                header[2] == 0x72.toByte() && header[3] == 0x21.toByte()
            ) return ComicSourceType.CBR
        }
        return when (fileName.substringAfterLast('.', "").lowercase()) {
            "pdf" -> ComicSourceType.PDF
            "cbr", "rar" -> ComicSourceType.CBR
            "jpg", "jpeg", "png", "webp", "bmp", "gif" -> ComicSourceType.IMAGES
            else -> ComicSourceType.CBZ
        }
    }

    private fun resolveDisplayName(uri: Uri): String? {
        runCatching {
            appContext.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) return cursor.getString(idx)
                    }
                }
        }
        return uri.lastPathSegment?.substringAfterLast('/')
    }

    private fun prettifyFileTitle(fileName: String): String {
        val noExt = fileName.substringBeforeLast('.', fileName)
        return noExt.replace('_', ' ').replace(Regex("\\s+"), " ").trim().ifBlank { fileName }
    }

    @Suppress("DEPRECATION")
    private fun saveBitmapAsWebp(bitmap: Bitmap, file: File) {
        val format = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Bitmap.CompressFormat.WEBP_LOSSY
        } else {
            Bitmap.CompressFormat.WEBP
        }
        FileOutputStream(file).use { out -> bitmap.compress(format, 84, out) }
    }

    private fun extractAccentHex(bitmap: Bitmap): String {
        var rSum = 0L
        var gSum = 0L
        var bSum = 0L
        var weightSum = 0L
        val stepX = (bitmap.width / 12).coerceAtLeast(1)
        val stepY = (bitmap.height / 12).coerceAtLeast(1)
        val hsv = FloatArray(3)
        var x = stepX
        while (x < bitmap.width) {
            var y = stepY
            while (y < bitmap.height) {
                val px = bitmap.getPixel(x, y)
                Color.colorToHSV(px, hsv)
                val sat = hsv[1]
                val value = hsv[2]
                if (sat > 0.28f && value in 0.25f..0.95f) {
                    val w = (sat * 100).toLong().coerceAtLeast(1L)
                    rSum += Color.red(px) * w
                    gSum += Color.green(px) * w
                    bSum += Color.blue(px) * w
                    weightSum += w
                }
                y += stepY
            }
            x += stepX
        }
        if (weightSum == 0L) return "#FFB703"
        val r = (rSum / weightSum).toInt().coerceIn(60, 245)
        val g = (gSum / weightSum).toInt().coerceIn(60, 245)
        val b = (bSum / weightSum).toInt().coerceIn(60, 245)
        return "#%02X%02X%02X".format(r, g, b)
    }

    private fun buildComicInfoXml(comic: ComicBook): String {
        fun esc(s: String) = s
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
        val mangaTag = if (comic.preferredMode == ReadingMode.PAGED_RTL) "YesAndRightToLeft" else "No"
        return """
            <?xml version="1.0" encoding="utf-8"?>
            <ComicInfo>
              <Title>${esc(comic.titleEn.ifBlank { comic.titleFa })}</Title>
              <Writer>${esc(comic.authorEn.ifBlank { comic.authorFa })}</Writer>
              <Genre>${esc(comic.genreEn.ifBlank { comic.genreFa })}</Genre>
              <Summary>${esc(comic.descriptionEn.ifBlank { comic.descriptionFa })}</Summary>
              <PageCount>${comic.pageCount}</PageCount>
              <Manga>$mangaTag</Manga>
            </ComicInfo>
        """.trimIndent()
    }
}
