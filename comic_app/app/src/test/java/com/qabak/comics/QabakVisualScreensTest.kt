package com.qabak.comics

import android.content.Context
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoStories
import androidx.compose.material.icons.outlined.Bookmarks
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.rounded.AutoStories
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.captureRoboImage
import com.qabak.comics.data.parser.BundledPageSource
import com.qabak.comics.data.parser.PageBitmapCache
import com.qabak.comics.model.AppLanguage
import com.qabak.comics.model.AppThemeMode
import com.qabak.comics.model.BookmarkItem
import com.qabak.comics.model.ComicBook
import com.qabak.comics.model.ComicSourceType
import com.qabak.comics.model.DialogueDisplayMode
import com.qabak.comics.model.ReadingMode
import com.qabak.comics.model.ReadingStats
import com.qabak.comics.model.UserSettings
import com.qabak.comics.ui.components.ImportSheetContent
import com.qabak.comics.ui.i18n.LocalAppStrings
import com.qabak.comics.ui.screens.bookmarks.BookmarksScreen
import com.qabak.comics.ui.screens.detail.ComicDetailScreen
import com.qabak.comics.ui.screens.library.LibraryScreen
import com.qabak.comics.ui.screens.reader.ReaderScreen
import com.qabak.comics.ui.screens.settings.SettingsScreen
import com.qabak.comics.ui.theme.QabakTheme
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w412dp-h915dp-xxhdpi")
class QabakVisualScreensTest {

    @get:Rule
    val composeRule = createComposeRule()

    private lateinit var context: Context
    private lateinit var sampleComics: List<ComicBook>
    private lateinit var alborzSource: BundledPageSource
    private lateinit var tehranSource: BundledPageSource
    private lateinit var webtoonSource: BundledPageSource
    private lateinit var mangaSource: BundledPageSource

    @Before
    fun setUp() = runBlocking {
        context = ApplicationProvider.getApplicationContext()
        alborzSource = BundledPageSource(context, "guardian_of_alborz")
        tehranSource = BundledPageSource(context, "neon_tehran_2099")
        webtoonSource = BundledPageSource(context, "desert_lantern_webtoon")
        mangaSource = BundledPageSource(context, "ink_blade_manga")

        val sources = listOf(alborzSource, tehranSource, webtoonSource, mangaSource)
        sampleComics = sources.mapIndexed { idx, src ->
            val m = src.manifest
            val coverPath = "asset://comics/${m.id}/${m.pages.first().file}"
            // Pre-decode cover into cache for instant crisp rendering
            val coverBmp = src.renderPage(0, maxWidth = 480, maxHeight = 720)
            if (coverBmp != null) {
                PageBitmapCache.put("cover:$coverPath:480", coverBmp)
            }
            ComicBook(
                id = "bundled_${m.id}",
                titleFa = m.titleFa,
                titleEn = m.titleEn,
                seriesFa = m.seriesFa,
                seriesEn = m.seriesEn,
                authorFa = m.authorFa,
                authorEn = m.authorEn,
                genreFa = m.genreFa,
                genreEn = m.genreEn,
                descriptionFa = m.descriptionFa,
                descriptionEn = m.descriptionEn,
                sourceType = ComicSourceType.BUNDLED,
                sourcePath = m.id,
                coverPath = coverPath,
                accentHex = m.accentHex,
                pageCount = m.pages.size,
                currentPage = if (idx == 0) 2 else 0,
                isFavorite = idx == 0 || idx == 1,
                isCompleted = idx == 2,
                preferredMode = ReadingMode.valueOf(m.defaultMode),
                addedAt = 1700000000000L - idx * 1000L,
                lastReadAt = if (idx == 0) 1700000050000L else 0L
            )
        }
    }

    @Test
    fun capture01_libraryPersianDark() {
        composeRule.setContent {
            QabakTheme(themeMode = AppThemeMode.DARK, language = AppLanguage.FA) {
                val s = LocalAppStrings.current
                Scaffold(
                    bottomBar = {
                        NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                            NavigationBarItem(
                                selected = true,
                                onClick = {},
                                icon = { Icon(Icons.Rounded.AutoStories, null) },
                                label = { Text(s.navLibrary) },
                                colors = NavigationBarItemDefaults.colors(
                                    selectedIconColor = MaterialTheme.colorScheme.onPrimary,
                                    selectedTextColor = MaterialTheme.colorScheme.primary,
                                    indicatorColor = MaterialTheme.colorScheme.primary
                                )
                            )
                            NavigationBarItem(
                                selected = false,
                                onClick = {},
                                icon = { Icon(Icons.Outlined.Bookmarks, null) },
                                label = { Text(s.navBookmarks) }
                            )
                            NavigationBarItem(
                                selected = false,
                                onClick = {},
                                icon = { Icon(Icons.Outlined.Settings, null) },
                                label = { Text(s.navSettings) }
                            )
                        }
                    }
                ) { pad ->
                    LibraryScreen(
                        comics = sampleComics,
                        gridColumnsPref = 2,
                        isImporting = false,
                        loadCover = { PageBitmapCache.get("cover:$it:480") },
                        onToggleLanguage = {},
                        onToggleGridMode = {},
                        onOpenImportSheet = {},
                        onOpenComicDetail = {},
                        onOpenComicReader = { _, _ -> },
                        onToggleFavorite = {},
                        modifier = Modifier.padding(bottom = pad.calculateBottomPadding())
                    )
                }
            }
        }
        composeRule.waitForIdle()
        composeRule.onRoot().captureRoboImage("../qa/screenshots/01_library_fa_dark.png")
    }

    @Test
    fun capture02_libraryEnglishWarmPaperLight() {
        composeRule.setContent {
            QabakTheme(themeMode = AppThemeMode.LIGHT, language = AppLanguage.EN) {
                val s = LocalAppStrings.current
                Scaffold(
                    bottomBar = {
                        NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                            NavigationBarItem(
                                selected = true,
                                onClick = {},
                                icon = { Icon(Icons.Rounded.AutoStories, null) },
                                label = { Text(s.navLibrary) },
                                colors = NavigationBarItemDefaults.colors(
                                    selectedIconColor = MaterialTheme.colorScheme.onPrimary,
                                    selectedTextColor = MaterialTheme.colorScheme.primary,
                                    indicatorColor = MaterialTheme.colorScheme.primary
                                )
                            )
                            NavigationBarItem(
                                selected = false,
                                onClick = {},
                                icon = { Icon(Icons.Outlined.Bookmarks, null) },
                                label = { Text(s.navBookmarks) }
                            )
                            NavigationBarItem(
                                selected = false,
                                onClick = {},
                                icon = { Icon(Icons.Outlined.Settings, null) },
                                label = { Text(s.navSettings) }
                            )
                        }
                    }
                ) { pad ->
                    LibraryScreen(
                        comics = sampleComics,
                        gridColumnsPref = 2,
                        isImporting = false,
                        loadCover = { PageBitmapCache.get("cover:$it:480") },
                        onToggleLanguage = {},
                        onToggleGridMode = {},
                        onOpenImportSheet = {},
                        onOpenComicDetail = {},
                        onOpenComicReader = { _, _ -> },
                        onToggleFavorite = {},
                        modifier = Modifier.padding(bottom = pad.calculateBottomPadding())
                    )
                }
            }
        }
        composeRule.waitForIdle()
        composeRule.onRoot().captureRoboImage("../qa/screenshots/02_library_en_light.png")
    }

    @Test
    fun capture03_comicDetailPersianDark() = runBlocking {
        val thumbs = (0 until alborzSource.pageCount).associateWith { idx ->
            alborzSource.renderPage(idx, maxWidth = 300, maxHeight = 450)
        }
        val bms = listOf(
            BookmarkItem(
                id = 1L,
                comicId = sampleComics[0].id,
                comicTitleFa = sampleComics[0].titleFa,
                comicTitleEn = sampleComics[0].titleEn,
                comicSourceType = ComicSourceType.BUNDLED,
                comicSourcePath = sampleComics[0].sourcePath,
                comicCoverPath = sampleComics[0].coverPath,
                comicPageCount = sampleComics[0].pageCount,
                pageIndex = 1,
                note = "کشف اسطرلاب طلایی سیمرغ در نیایشگاه کوهستان",
                createdAt = 1700000060000L
            )
        )

        composeRule.setContent {
            QabakTheme(themeMode = AppThemeMode.DARK, language = AppLanguage.FA) {
                ComicDetailScreen(
                    comic = sampleComics[0],
                    bookmarks = bms,
                    loadCover = { PageBitmapCache.get("cover:$it:480") },
                    loadPageThumb = { idx -> thumbs[idx] },
                    onBack = {},
                    onOpenReader = { _, _ -> },
                    onToggleFavorite = {},
                    onToggleCompleted = {},
                    onSelectMode = {},
                    onShareCbz = {},
                    onDeleteComic = {}
                )
            }
        }
        composeRule.waitForIdle()
        composeRule.onRoot().captureRoboImage("../qa/screenshots/03_detail_fa_dark.png")
    }

    @Test
    fun capture04_readerPersianStoryPage() = runBlocking {
        // Pre-warm full-res page 1 bitmap
        alborzSource.renderPage(1, maxWidth = 1440, maxHeight = 2200)

        composeRule.setContent {
            QabakTheme(themeMode = AppThemeMode.DARK, language = AppLanguage.FA) {
                ReaderScreen(
                    comic = sampleComics[0],
                    source = alborzSource,
                    initialPage = 1,
                    initialMode = ReadingMode.PAGED_RTL,
                    settings = UserSettings(
                        language = AppLanguage.FA,
                        dialogueMode = DialogueDisplayMode.FA
                    ),
                    bookmarkedPages = setOf(1),
                    bookmarkNotes = mapOf(1 to "اسطرلاب سیمرغ"),
                    initialHudVisible = true,
                    onBack = {},
                    onPageChanged = {},
                    onModeChanged = {},
                    onPageFitChanged = {},
                    onColorFilterChanged = {},
                    onBackgroundChanged = {},
                    onDialogueModeChanged = {},
                    onBrightnessChanged = {},
                    onNightWarmthChanged = {},
                    onToggleVolumeKeys = {},
                    onToggleBookmark = {},
                    onSaveBookmarkNote = { _, _ -> }
                )
            }
        }
        composeRule.waitForIdle()
        Thread.sleep(250)
        composeRule.waitForIdle()
        composeRule.onRoot().captureRoboImage("../qa/screenshots/04_reader_fa_paged.png")
    }

    @Test
    fun capture05_readerEnglishCyberpunkActionPage() = runBlocking {
        tehranSource.renderPage(4, maxWidth = 1440, maxHeight = 2200)

        composeRule.setContent {
            QabakTheme(themeMode = AppThemeMode.DARK, language = AppLanguage.EN) {
                ReaderScreen(
                    comic = sampleComics[1],
                    source = tehranSource,
                    initialPage = 4,
                    initialMode = ReadingMode.PAGED_LTR,
                    settings = UserSettings(
                        language = AppLanguage.EN,
                        dialogueMode = DialogueDisplayMode.EN
                    ),
                    bookmarkedPages = emptySet(),
                    bookmarkNotes = emptyMap(),
                    initialHudVisible = true,
                    onBack = {},
                    onPageChanged = {},
                    onModeChanged = {},
                    onPageFitChanged = {},
                    onColorFilterChanged = {},
                    onBackgroundChanged = {},
                    onDialogueModeChanged = {},
                    onBrightnessChanged = {},
                    onNightWarmthChanged = {},
                    onToggleVolumeKeys = {},
                    onToggleBookmark = {},
                    onSaveBookmarkNote = { _, _ -> }
                )
            }
        }
        composeRule.waitForIdle()
        Thread.sleep(250)
        composeRule.waitForIdle()
        composeRule.onRoot().captureRoboImage("../qa/screenshots/05_reader_en_cyberpunk.png")
    }

    @Test
    fun capture06_bookmarksAndSettingsAndImportPersian() = runBlocking {
        val t1 = alborzSource.renderPage(1, 320, 480)
        val t2 = tehranSource.renderPage(3, 320, 480)
        val bookmarks = listOf(
            BookmarkItem(
                id = 1L,
                comicId = sampleComics[0].id,
                comicTitleFa = sampleComics[0].titleFa,
                comicTitleEn = sampleComics[0].titleEn,
                comicSourceType = ComicSourceType.BUNDLED,
                comicSourcePath = sampleComics[0].sourcePath,
                comicCoverPath = sampleComics[0].coverPath,
                comicPageCount = 5,
                pageIndex = 1,
                note = "ورود آرش به نیایشگاه کهن دماوند و درخشش اسطرلاب",
                createdAt = 1700000100000L
            ),
            BookmarkItem(
                id = 2L,
                comicId = sampleComics[1].id,
                comicTitleFa = sampleComics[1].titleFa,
                comicTitleEn = sampleComics[1].titleEn,
                comicSourceType = ComicSourceType.BUNDLED,
                comicSourcePath = sampleComics[1].sourcePath,
                comicCoverPath = sampleComics[1].coverPath,
                comicPageCount = 5,
                pageIndex = 3,
                note = "صحنه پرش تارا از میان پهپادها روی بام‌های بارانی تهران",
                createdAt = 1700000080000L
            )
        )

        composeRule.setContent {
            QabakTheme(themeMode = AppThemeMode.DARK, language = AppLanguage.FA) {
                BookmarksScreen(
                    stats = ReadingStats(
                        totalComics = 3,
                        completedComics = 1,
                        inProgressComics = 1,
                        totalPagesRead = 11,
                        totalBookmarks = 2
                    ),
                    bookmarks = bookmarks,
                    loadBookmarkThumb = { bm -> if (bm.id == 1L) t1 else t2 },
                    onOpenBookmark = {},
                    onUpdateNote = { _, _ -> },
                    onDeleteBookmark = {}
                )
            }
        }
        composeRule.waitForIdle()
        composeRule.onRoot().captureRoboImage("../qa/screenshots/06_bookmarks_fa.png")
    }

    @Test
    fun capture07_settingsPersianDark() {
        composeRule.setContent {
            QabakTheme(themeMode = AppThemeMode.DARK, language = AppLanguage.FA) {
                SettingsScreen(
                    settings = UserSettings(language = AppLanguage.FA, themeMode = AppThemeMode.DARK),
                    storageUsedBytes = 4_120_000L,
                    onSelectLanguage = {},
                    onSelectTheme = {},
                    onSelectDefaultMode = {},
                    onSelectDialogueMode = {},
                    onToggleVolumeKeys = {},
                    onToggleKeepScreenOn = {},
                    onTogglePageOverlay = {},
                    onClearCache = {},
                    onRestoreSamples = {}
                )
            }
        }
        composeRule.waitForIdle()
        composeRule.onRoot().captureRoboImage("../qa/screenshots/07_settings_fa.png")
    }

    @Test
    fun capture08_importSheetPersianDark() {
        composeRule.setContent {
            QabakTheme(themeMode = AppThemeMode.DARK, language = AppLanguage.FA) {
                Surface(
                    color = MaterialTheme.colorScheme.surface,
                    modifier = Modifier.fillMaxSize()
                ) {
                    Box(modifier = Modifier.fillMaxSize()) {
                        ImportSheetContent(
                            onPickComicFile = {},
                            onPickFolder = {},
                            onPickImages = {}
                        )
                    }
                }
            }
        }
        composeRule.waitForIdle()
        composeRule.onRoot().captureRoboImage("../qa/screenshots/08_import_sheet_fa.png")
    }

    @Test
    fun capture09_readerPersianDesertWebtoon() = runBlocking {
        webtoonSource.renderPage(3, maxWidth = 1440, maxHeight = 2200)

        composeRule.setContent {
            QabakTheme(themeMode = AppThemeMode.DARK, language = AppLanguage.FA) {
                ReaderScreen(
                    comic = sampleComics[2],
                    source = webtoonSource,
                    initialPage = 3,
                    initialMode = ReadingMode.PAGED_RTL,
                    settings = UserSettings(
                        language = AppLanguage.FA,
                        dialogueMode = DialogueDisplayMode.FA
                    ),
                    bookmarkedPages = setOf(3),
                    bookmarkNotes = mapOf(3 to "چشمه آینه و بادگیرها"),
                    initialHudVisible = true,
                    onBack = {},
                    onPageChanged = {},
                    onModeChanged = {},
                    onPageFitChanged = {},
                    onColorFilterChanged = {},
                    onBackgroundChanged = {},
                    onDialogueModeChanged = {},
                    onBrightnessChanged = {},
                    onNightWarmthChanged = {},
                    onToggleVolumeKeys = {},
                    onToggleBookmark = {},
                    onSaveBookmarkNote = { _, _ -> }
                )
            }
        }
        composeRule.waitForIdle()
        Thread.sleep(250)
        composeRule.waitForIdle()
        composeRule.onRoot().captureRoboImage("../qa/screenshots/09_reader_fa_webtoon.png")
    }

    @Test
    fun capture10_readerPersianSamuraiManga() = runBlocking {
        mangaSource.renderPage(3, maxWidth = 1440, maxHeight = 2200)

        composeRule.setContent {
            QabakTheme(themeMode = AppThemeMode.DARK, language = AppLanguage.FA) {
                ReaderScreen(
                    comic = sampleComics[3],
                    source = mangaSource,
                    initialPage = 3,
                    initialMode = ReadingMode.PAGED_RTL,
                    settings = UserSettings(
                        language = AppLanguage.FA,
                        dialogueMode = DialogueDisplayMode.FA
                    ),
                    bookmarkedPages = emptySet(),
                    bookmarkNotes = emptyMap(),
                    initialHudVisible = true,
                    onBack = {},
                    onPageChanged = {},
                    onModeChanged = {},
                    onPageFitChanged = {},
                    onColorFilterChanged = {},
                    onBackgroundChanged = {},
                    onDialogueModeChanged = {},
                    onBrightnessChanged = {},
                    onNightWarmthChanged = {},
                    onToggleVolumeKeys = {},
                    onToggleBookmark = {},
                    onSaveBookmarkNote = { _, _ -> }
                )
            }
        }
        composeRule.waitForIdle()
        Thread.sleep(250)
        composeRule.waitForIdle()
        composeRule.onRoot().captureRoboImage("../qa/screenshots/10_reader_fa_manga.png")
    }
}
