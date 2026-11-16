package com.qabak.comics.model

import kotlinx.serialization.Serializable

enum class AppLanguage(val code: String) {
    FA("fa"),
    EN("en");

    val isRtl: Boolean get() = this == FA
}

enum class AppThemeMode {
    DARK,
    LIGHT,
    AMOLED
}

enum class ReadingMode {
    PAGED_RTL,
    PAGED_LTR,
    WEBTOON,
    GUIDED_PANEL
}

enum class PageFitMode {
    FIT_WIDTH,
    FIT_PAGE,
    FIT_HEIGHT
}

enum class ReaderColorFilter {
    NONE,
    SEPIA,
    GRAYSCALE,
    HIGH_CONTRAST
}

enum class ReaderBackground {
    BLACK,
    SEPIA,
    WHITE
}

enum class DialogueDisplayMode {
    MATCH_APP,
    FA,
    EN,
    HIDDEN
}

enum class ComicSourceType(val badge: String) {
    BUNDLED("QABAK"),
    CBZ("CBZ"),
    CBR("CBR"),
    PDF("PDF"),
    IMAGES("IMG"),
    FOLDER("DIR")
}

enum class LibraryFilter {
    ALL,
    READING,
    COMPLETED,
    FAVORITES,
    IMPORTED
}

enum class LibrarySort {
    RECENT,
    TITLE,
    PROGRESS,
    DATE_ADDED
}

data class UserSettings(
    val language: AppLanguage = AppLanguage.FA,
    val themeMode: AppThemeMode = AppThemeMode.DARK,
    val defaultReadingMode: ReadingMode = ReadingMode.PAGED_RTL,
    val pageFitMode: PageFitMode = PageFitMode.FIT_PAGE,
    val colorFilter: ReaderColorFilter = ReaderColorFilter.NONE,
    val readerBackground: ReaderBackground = ReaderBackground.BLACK,
    val dialogueMode: DialogueDisplayMode = DialogueDisplayMode.MATCH_APP,
    val volumeKeysNavigation: Boolean = true,
    val keepScreenOn: Boolean = true,
    val showPageNumberOverlay: Boolean = true,
    val brightnessOverride: Float = -1f, // -1f = follow system brightness, 0.1f..1.0f = custom
    val nightWarmth: Float = 0f,         // 0f..0.45f warm amber eye-comfort overlay
    val gridColumns: Int = 2,            // 2 = comfortable grid, 1 = detailed list
    val seededVersion: Int = 0
)

data class ComicBook(
    val id: String,
    val titleFa: String,
    val titleEn: String,
    val seriesFa: String,
    val seriesEn: String,
    val authorFa: String,
    val authorEn: String,
    val genreFa: String,
    val genreEn: String,
    val descriptionFa: String,
    val descriptionEn: String,
    val sourceType: ComicSourceType,
    val sourcePath: String,
    val coverPath: String,
    val accentHex: String,
    val pageCount: Int,
    val currentPage: Int,
    val isFavorite: Boolean,
    val isCompleted: Boolean,
    val preferredMode: ReadingMode,
    val addedAt: Long,
    val lastReadAt: Long
) {
    fun localizedTitle(lang: AppLanguage): String =
        if (lang == AppLanguage.FA) titleFa.ifBlank { titleEn } else titleEn.ifBlank { titleFa }

    fun localizedSeries(lang: AppLanguage): String =
        if (lang == AppLanguage.FA) seriesFa.ifBlank { seriesEn } else seriesEn.ifBlank { seriesFa }

    fun localizedAuthor(lang: AppLanguage): String =
        if (lang == AppLanguage.FA) authorFa.ifBlank { authorEn } else authorEn.ifBlank { authorFa }

    fun localizedGenre(lang: AppLanguage): String =
        if (lang == AppLanguage.FA) genreFa.ifBlank { genreEn } else genreEn.ifBlank { genreFa }

    fun localizedDescription(lang: AppLanguage): String =
        if (lang == AppLanguage.FA) descriptionFa.ifBlank { descriptionEn } else descriptionEn.ifBlank { descriptionFa }

    val progressFraction: Float
        get() = when {
            isCompleted -> 1f
            pageCount <= 0 -> 0f
            lastReadAt <= 0L && currentPage == 0 -> 0f
            else -> ((currentPage + 1).toFloat() / pageCount.toFloat()).coerceIn(0f, 1f)
        }

    val progressPercent: Int
        get() = (progressFraction * 100f).toInt().coerceIn(0, 100)

    val isStarted: Boolean
        get() = lastReadAt > 0L || currentPage > 0 || isCompleted
}

data class BookmarkItem(
    val id: Long,
    val comicId: String,
    val comicTitleFa: String,
    val comicTitleEn: String,
    val comicSourceType: ComicSourceType,
    val comicSourcePath: String,
    val comicCoverPath: String,
    val comicPageCount: Int,
    val pageIndex: Int,
    val note: String,
    val createdAt: Long
) {
    fun localizedComicTitle(lang: AppLanguage): String =
        if (lang == AppLanguage.FA) comicTitleFa.ifBlank { comicTitleEn } else comicTitleEn.ifBlank { comicTitleFa }
}

data class ReadingStats(
    val totalComics: Int = 0,
    val completedComics: Int = 0,
    val inProgressComics: Int = 0,
    val totalPagesRead: Int = 0,
    val totalBookmarks: Int = 0
)

@Serializable
data class BundledCatalog(
    val version: Int = 1,
    val comics: List<String> = emptyList()
)

@Serializable
data class BundledComicManifest(
    val id: String,
    val titleFa: String,
    val titleEn: String,
    val seriesFa: String = "",
    val seriesEn: String = "",
    val authorFa: String = "",
    val authorEn: String = "",
    val genreFa: String = "",
    val genreEn: String = "",
    val descriptionFa: String = "",
    val descriptionEn: String = "",
    val accentHex: String = "#FFB703",
    val defaultMode: String = "PAGED_RTL",
    val pages: List<BundledPageMeta> = emptyList()
)

@Serializable
data class BundledPageMeta(
    val file: String,
    val width: Int = 900,
    val height: Int = 1350,
    val isCover: Boolean = false,
    val titleFa: String = "",
    val titleEn: String = "",
    val panels: List<PanelRect> = emptyList(),
    val bubbles: List<DialogueBubble> = emptyList()
)

@Serializable
data class PanelRect(
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float
) {
    val width: Float get() = (right - left).coerceAtLeast(0.05f)
    val height: Float get() = (bottom - top).coerceAtLeast(0.05f)
    val centerX: Float get() = (left + right) * 0.5f
    val centerY: Float get() = (top + bottom) * 0.5f
}

@Serializable
data class DialogueBubble(
    val x: Float,
    val y: Float,
    val width: Float = 0.5f,
    val style: String = "SPEECH", // SPEECH, CAPTION, SHOUT, SFX, COVER_TITLE
    val tailDir: String = "NONE", // UP, DOWN, NONE
    val textFa: String = "",
    val textEn: String = "",
    val subFa: String = "",
    val subEn: String = ""
) {
    fun textFor(lang: AppLanguage): String =
        if (lang == AppLanguage.FA) textFa.ifBlank { textEn } else textEn.ifBlank { textFa }

    fun subFor(lang: AppLanguage): String =
        if (lang == AppLanguage.FA) subFa.ifBlank { subEn } else subEn.ifBlank { subFa }
}

data class ComicInfoMetadata(
    val title: String? = null,
    val series: String? = null,
    val number: String? = null,
    val writer: String? = null,
    val summary: String? = null,
    val genre: String? = null,
    val isMangaRtl: Boolean = false
)
