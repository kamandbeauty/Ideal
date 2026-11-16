package com.qabak.comics.ui.i18n

import androidx.compose.runtime.compositionLocalOf
import com.qabak.comics.model.AppLanguage
import com.qabak.comics.model.AppThemeMode
import com.qabak.comics.model.DialogueDisplayMode
import com.qabak.comics.model.LibraryFilter
import com.qabak.comics.model.LibrarySort
import com.qabak.comics.model.PageFitMode
import com.qabak.comics.model.ReaderBackground
import com.qabak.comics.model.ReaderColorFilter
import com.qabak.comics.model.ReadingMode
import java.util.Locale

data class AppStrings(
    val language: AppLanguage,
    val appName: String,
    val appTagline: String,
    val langToggleBadge: String,

    // Bottom Navigation
    val navLibrary: String,
    val navBookmarks: String,
    val navSettings: String,

    // Library Screen
    val searchPlaceholder: String,
    val continueReading: String,
    val resumeButton: String,
    val startReading: String,
    val readAgain: String,
    val importComic: String,
    val shelfSectionTitle: String,
    val filterAll: String,
    val filterReading: String,
    val filterCompleted: String,
    val filterFavorites: String,
    val filterImported: String,
    val sortLabel: String,
    val sortRecent: String,
    val sortTitle: String,
    val sortProgress: String,
    val sortAdded: String,
    val emptyLibraryTitle: String,
    val emptyLibrarySubtitle: String,
    val emptyFilterTitle: String,
    val emptyFilterSubtitle: String,
    val originalBadge: String,
    val completedBadge: String,
    val newBadge: String,
    val importingInProgress: String,
    val importSuccess: String,
    val importErrorGeneric: String,
    val importErrorRar5: String,
    val importErrorEmpty: String,

    // Import Sheet & Custom Title Dialog
    val importSheetTitle: String,
    val importSheetSubtitle: String,
    val importFileTitle: String,
    val importFileDesc: String,
    val importFolderTitle: String,
    val importFolderDesc: String,
    val importImagesTitle: String,
    val importImagesDesc: String,
    val supportedFormatsHint: String,
    val imageCollectionDialogTitle: String,
    val imageCollectionNameLabel: String,
    val imageCollectionDefaultName: String,
    val confirmAction: String,
    val cancelAction: String,

    // Detail Screen
    val backAction: String,
    val favoriteAction: String,
    val unfavoriteAction: String,
    val markCompleted: String,
    val markUnread: String,
    val shareCbzAction: String,
    val deleteAction: String,
    val deleteDialogTitle: String,
    val deleteDialogBody: String,
    val synopsisTitle: String,
    val noSynopsis: String,
    val readingModeTitle: String,
    val pagesPreviewTitle: String,
    val comicBookmarksTitle: String,
    val unknownAuthor: String,
    val exportingComic: String,

    // Reader Screen
    val modePagedRtl: String,
    val modePagedLtr: String,
    val modeWebtoon: String,
    val modeGuidedPanel: String,
    val modeShortRtl: String,
    val modeShortLtr: String,
    val modeShortWebtoon: String,
    val modeShortPanel: String,
    val fitWidth: String,
    val fitPage: String,
    val fitHeight: String,
    val filterNone: String,
    val filterSepia: String,
    val filterGrayscale: String,
    val filterContrast: String,
    val bgBlack: String,
    val bgSepia: String,
    val bgWhite: String,
    val dialogueTitle: String,
    val dialogueMatchApp: String,
    val dialogueFa: String,
    val dialogueEn: String,
    val dialogueHidden: String,
    val readerSettingsTitle: String,
    val pageFitTitle: String,
    val colorFilterTitle: String,
    val backgroundTitle: String,
    val brightnessTitle: String,
    val brightnessAuto: String,
    val nightLightTitle: String,
    val bookmarkAdded: String,
    val bookmarkRemoved: String,
    val addBookmarkNote: String,
    val editBookmarkNote: String,
    val bookmarkNoteHint: String,
    val saveAction: String,
    val pageListTitle: String,
    val previousPage: String,
    val nextPage: String,
    val endOfComicToast: String,
    val panelIndicatorLabel: String,
    val loadingPage: String,
    val pageLoadError: String,

    // Bookmarks & Stats Screen
    val statsHeaderTitle: String,
    val statBooks: String,
    val statCompleted: String,
    val statPagesRead: String,
    val statBookmarks: String,
    val emptyBookmarksTitle: String,
    val emptyBookmarksSubtitle: String,
    val openPageAction: String,

    // Settings Screen
    val settingsAppearanceSection: String,
    val settingsLanguageLabel: String,
    val settingsThemeLabel: String,
    val themeDark: String,
    val themeLight: String,
    val themeAmoled: String,
    val settingsReaderSection: String,
    val settingsDefaultModeLabel: String,
    val settingsVolumeKeysLabel: String,
    val settingsVolumeKeysDesc: String,
    val settingsKeepScreenOnLabel: String,
    val settingsKeepScreenOnDesc: String,
    val settingsPageOverlayLabel: String,
    val settingsPageOverlayDesc: String,
    val settingsStorageSection: String,
    val settingsStorageUsedLabel: String,
    val settingsClearCacheAction: String,
    val settingsCacheClearedToast: String,
    val settingsRestoreSamplesLabel: String,
    val settingsRestoreSamplesDesc: String,
    val settingsSamplesRestoredToast: String,
    val settingsSamplesAlreadyPresent: String,
    val settingsAboutTitle: String,
    val settingsAboutSubtitle: String
) {
    fun pagesCount(count: Int): String {
        val n = localizeDigits(count.toString(), language)
        return if (language == AppLanguage.FA) "$n صفحه" else if (count == 1) "1 page" else "$n pages"
    }

    fun pageOfTotal(pageZeroBased: Int, total: Int): String {
        val safeTotal = total.coerceAtLeast(1)
        val cur = (pageZeroBased + 1).coerceIn(1, safeTotal)
        val c = localizeDigits(cur.toString(), language)
        val t = localizeDigits(safeTotal.toString(), language)
        return if (language == AppLanguage.FA) "صفحه $c از $t" else "Page $c of $t"
    }

    fun compactPageFraction(pageZeroBased: Int, total: Int): String {
        val safeTotal = total.coerceAtLeast(1)
        val cur = (pageZeroBased + 1).coerceIn(1, safeTotal)
        val c = localizeDigits(cur.toString(), language)
        val t = localizeDigits(safeTotal.toString(), language)
        return "$c / $t"
    }

    fun continueFromPage(pageZeroBased: Int): String {
        val p = localizeDigits((pageZeroBased + 1).toString(), language)
        return if (language == AppLanguage.FA) "ادامه از صفحه $p" else "Continue · p. $p"
    }

    fun pageNumberLabel(pageZeroBased: Int): String {
        val p = localizeDigits((pageZeroBased + 1).toString(), language)
        return if (language == AppLanguage.FA) "صفحه $p" else "Page $p"
    }

    fun panelOfTotal(panelZeroBased: Int, totalPanels: Int): String {
        val p = localizeDigits((panelZeroBased + 1).coerceAtLeast(1).toString(), language)
        val t = localizeDigits(totalPanels.coerceAtLeast(1).toString(), language)
        return if (language == AppLanguage.FA) "قاب $p از $t" else "Panel $p/$t"
    }

    fun percent(value: Int): String {
        val n = localizeDigits(value.coerceIn(0, 100).toString(), language)
        return if (language == AppLanguage.FA) "٪$n" else "$n%"
    }

    fun number(value: Int): String = localizeDigits(value.toString(), language)

    fun filterLabel(filter: LibraryFilter): String = when (filter) {
        LibraryFilter.ALL -> filterAll
        LibraryFilter.READING -> filterReading
        LibraryFilter.COMPLETED -> filterCompleted
        LibraryFilter.FAVORITES -> filterFavorites
        LibraryFilter.IMPORTED -> filterImported
    }

    fun sortLabelFor(sort: LibrarySort): String = when (sort) {
        LibrarySort.RECENT -> sortRecent
        LibrarySort.TITLE -> sortTitle
        LibrarySort.PROGRESS -> sortProgress
        LibrarySort.DATE_ADDED -> sortAdded
    }

    fun modeLabel(mode: ReadingMode): String = when (mode) {
        ReadingMode.PAGED_RTL -> modePagedRtl
        ReadingMode.PAGED_LTR -> modePagedLtr
        ReadingMode.WEBTOON -> modeWebtoon
        ReadingMode.GUIDED_PANEL -> modeGuidedPanel
    }

    fun modeShortLabel(mode: ReadingMode): String = when (mode) {
        ReadingMode.PAGED_RTL -> modeShortRtl
        ReadingMode.PAGED_LTR -> modeShortLtr
        ReadingMode.WEBTOON -> modeShortWebtoon
        ReadingMode.GUIDED_PANEL -> modeShortPanel
    }

    fun fitLabel(fit: PageFitMode): String = when (fit) {
        PageFitMode.FIT_WIDTH -> fitWidth
        PageFitMode.FIT_PAGE -> fitPage
        PageFitMode.FIT_HEIGHT -> fitHeight
    }

    fun filterColorLabel(f: ReaderColorFilter): String = when (f) {
        ReaderColorFilter.NONE -> filterNone
        ReaderColorFilter.SEPIA -> filterSepia
        ReaderColorFilter.GRAYSCALE -> filterGrayscale
        ReaderColorFilter.HIGH_CONTRAST -> filterContrast
    }

    fun bgLabel(bg: ReaderBackground): String = when (bg) {
        ReaderBackground.BLACK -> bgBlack
        ReaderBackground.SEPIA -> bgSepia
        ReaderBackground.WHITE -> bgWhite
    }

    fun themeLabel(theme: AppThemeMode): String = when (theme) {
        AppThemeMode.DARK -> themeDark
        AppThemeMode.LIGHT -> themeLight
        AppThemeMode.AMOLED -> themeAmoled
    }

    fun dialogueLabel(mode: DialogueDisplayMode): String = when (mode) {
        DialogueDisplayMode.MATCH_APP -> dialogueMatchApp
        DialogueDisplayMode.FA -> dialogueFa
        DialogueDisplayMode.EN -> dialogueEn
        DialogueDisplayMode.HIDDEN -> dialogueHidden
    }
}

val FaStrings = AppStrings(
    language = AppLanguage.FA,
    appName = "قابک",
    appTagline = "کتابخانه و کامیک‌خوان",
    langToggleBadge = "EN",

    navLibrary = "کتابخانه",
    navBookmarks = "نشانک‌ها",
    navSettings = "تنظیمات",

    searchPlaceholder = "جستجوی عنوان، نویسنده یا ژانر...",
    continueReading = "ادامه مطالعه",
    resumeButton = "ادامه",
    startReading = "شروع مطالعه",
    readAgain = "مطالعه دوباره",
    importComic = "افزودن کامیک",
    shelfSectionTitle = "قفسه کتاب‌ها",
    filterAll = "همه",
    filterReading = "در حال مطالعه",
    filterCompleted = "خوانده‌شده",
    filterFavorites = "محبوب‌ها",
    filterImported = "واردشده",
    sortLabel = "مرتب‌سازی",
    sortRecent = "آخرین مطالعه",
    sortTitle = "حروف الفبا",
    sortProgress = "میزان پیشرفت",
    sortAdded = "جدیدترین",
    emptyLibraryTitle = "قفسه شما خالی است",
    emptyLibrarySubtitle = "فایل‌های CBZ، CBR، PDF یا پوشه تصاویر کمیک خود را وارد کنید یا کامیک‌های نمونه را از تنظیمات بازگردانید.",
    emptyFilterTitle = "موردی پیدا نشد",
    emptyFilterSubtitle = "فیلتر انتخاب‌شده یا عبارت جستجو را تغییر دهید.",
    originalBadge = "ویژه",
    completedBadge = "تمام‌شده",
    newBadge = "جدید",
    importingInProgress = "در حال آماده‌سازی و افزودن به قفسه...",
    importSuccess = "با موفقیت به کتابخانه اضافه شد",
    importErrorGeneric = "باز کردن این فایل ممکن نشد. از سالم بودن فایل مطمئن شوید.",
    importErrorRar5 = "این فایل با نسخه RAR5 فشرده شده است؛ لطفاً آن را به CBZ یا PDF تبدیل کنید.",
    importErrorEmpty = "هیچ صفحه قابل نمایشی در فایل انتخابی پیدا نشد.",

    importSheetTitle = "افزودن کامیک به قفسه",
    importSheetSubtitle = "فایل‌های کامیک، کتاب‌های PDF یا مجموعه تصاویر گوشی را انتخاب کنید",
    importFileTitle = "انتخاب فایل کامیک (CBZ / CBR / PDF)",
    importFileDesc = "پشتیبانی از آرشیوهای کمیک همراه با متادیتای ComicInfo و فایل‌های PDF",
    importFolderTitle = "انتخاب پوشه تصاویر",
    importFolderDesc = "مرتب‌سازی هوشمند شماره‌گذاری صفحات داخل یک پوشه",
    importImagesTitle = "ساخت کامیک از چند تصویر",
    importImagesDesc = "انتخاب چند عکس از گالری و تبدیل یکجا به یک جلد کامیک",
    supportedFormatsHint = "فرمت‌های پشتیبانی‌شده: CBZ • ZIP • CBR • PDF • JPG • PNG • WEBP",
    imageCollectionDialogTitle = "عنوان کامیک جدید",
    imageCollectionNameLabel = "نام این مجموعه تصویری",
    imageCollectionDefaultName = "کامیک من",
    confirmAction = "تأیید و ساخت",
    cancelAction = "انصراف",

    backAction = "بازگشت",
    favoriteAction = "افزودن به محبوب‌ها",
    unfavoriteAction = "حذف از محبوب‌ها",
    markCompleted = "علامت خوانده‌شده",
    markUnread = "بازنشانی پیشرفت",
    shareCbzAction = "اشتراک‌گذاری CBZ",
    deleteAction = "حذف",
    deleteDialogTitle = "حذف از کتابخانه؟",
    deleteDialogBody = "این کامیک و نشانک‌های آن از کتابخانه حذف می‌شود. کامیک‌های نمونه را همیشه می‌توانید از تنظیمات برگردانید.",
    synopsisTitle = "خلاصه داستان",
    noSynopsis = "توضیحی برای این کامیک ثبت نشده است.",
    readingModeTitle = "حالت مطالعه این کتاب",
    pagesPreviewTitle = "مرور صفحات",
    comicBookmarksTitle = "نشانک‌های این کتاب",
    unknownAuthor = "فایل شخصی",
    exportingComic = "در حال آماده‌سازی فایل CBZ برای اشتراک‌گذاری...",

    modePagedRtl = "ورق‌زدنی راست‌به‌چپ (فارسی / مانگا)",
    modePagedLtr = "ورق‌زدنی چپ‌به‌راست (کمیک غربی)",
    modeWebtoon = "اسکرول عمودی پیوسته (وب‌تون)",
    modeGuidedPanel = "نمای هوشمند قاب‌به‌قاب",
    modeShortRtl = "راست‌به‌چپ",
    modeShortLtr = "چپ‌به‌راست",
    modeShortWebtoon = "وب‌تون",
    modeShortPanel = "قاب‌به‌قاب",
    fitWidth = "تنظیم با عرض",
    fitPage = "تمام‌صفحه",
    fitHeight = "تنظیم با ارتفاع",
    filterNone = "اصلی",
    filterSepia = "سپیا (شب)",
    filterGrayscale = "سیاه‌وسفید",
    filterContrast = "جوهر پررنگ",
    bgBlack = "تاریک",
    bgSepia = "کاغذی",
    bgWhite = "روشن",
    dialogueTitle = "زبان دیالوگ کامیک‌های نمونه",
    dialogueMatchApp = "هماهنگ با اپ",
    dialogueFa = "فارسی",
    dialogueEn = "English",
    dialogueHidden = "فقط تصویر",
    readerSettingsTitle = "تنظیمات مطالعه",
    pageFitTitle = "اندازه صفحه",
    colorFilterTitle = "فیلتر رنگ",
    backgroundTitle = "پس‌زمینه صفحه",
    brightnessTitle = "روشنایی صفحه",
    brightnessAuto = "خودکار",
    nightLightTitle = "فیلتر نور گرم (محافظ چشم)",
    bookmarkAdded = "صفحه نشانه‌گذاری شد",
    bookmarkRemoved = "نشانک حذف شد",
    addBookmarkNote = "یادداشت برای نشانک",
    editBookmarkNote = "ویرایش یادداشت نشانک",
    bookmarkNoteHint = "مثلاً: صحنه بیداری سیمرغ یا دیالوگ محبوب...",
    saveAction = "ذخیره",
    pageListTitle = "پرش سریع به صفحه",
    previousPage = "صفحه قبل",
    nextPage = "صفحه بعد",
    endOfComicToast = "به پایان این شماره رسیدید!",
    panelIndicatorLabel = "نمای قاب‌به‌قاب",
    loadingPage = "در حال بارگذاری صفحه...",
    pageLoadError = "نمایش این صفحه ممکن نشد",

    statsHeaderTitle = "کارنامه مطالعه شما",
    statBooks = "کتاب‌ها",
    statCompleted = "خوانده‌شده",
    statPagesRead = "صفحات",
    statBookmarks = "نشانک‌ها",
    emptyBookmarksTitle = "هنوز صفحه‌ای نشانک نشده",
    emptyBookmarksSubtitle = "هنگام مطالعه کامیک، روی آیکون نشانک در نوار بالا بزنید تا صفحات محبوبتان همراه با یادداشت اینجا ذخیره شوند.",
    openPageAction = "مشاهده صفحه",

    settingsAppearanceSection = "ظاهر و زبان",
    settingsLanguageLabel = "زبان برنامه",
    settingsThemeLabel = "پوسته ظاهری",
    themeDark = "تاریک جوهری",
    themeLight = "روشن کاغذی",
    themeAmoled = "مشکی OLED",
    settingsReaderSection = "تجربه مطالعه",
    settingsDefaultModeLabel = "جهت مطالعه پیش‌فرض",
    settingsVolumeKeysLabel = "ورق زدن با دکمه‌های صدا",
    settingsVolumeKeysDesc = "جابه‌جایی بین صفحات یا قاب‌ها با کلید کم و زیاد صدا",
    settingsKeepScreenOnLabel = "روشن ماندن صفحه هنگام مطالعه",
    settingsKeepScreenOnDesc = "جلوگیری از خاموش شدن خودکار نمایشگر در صفحه خواننده",
    settingsPageOverlayLabel = "نمایش شمارنده کوچک صفحه",
    settingsPageOverlayDesc = "نمایش شماره صفحه در گوشه پایین هنگام تمام‌صفحه بودن",
    settingsStorageSection = "حافظه و محتوا",
    settingsStorageUsedLabel = "فضای اشغال‌شده فایل‌های واردشده",
    settingsClearCacheAction = "پاک‌سازی حافظه موقت",
    settingsCacheClearedToast = "حافظه موقت پاک‌سازی شد",
    settingsRestoreSamplesLabel = "بازگردانی کامیک‌های نمونه",
    settingsRestoreSamplesDesc = "افزودن دوباره کامیک‌های تصویرسازی‌شده قابک در صورت حذف",
    settingsSamplesRestoredToast = "کامیک‌های نمونه به کتابخانه بازگردانده شدند",
    settingsSamplesAlreadyPresent = "همه کامیک‌های نمونه در کتابخانه موجودند",
    settingsAboutTitle = "قابک • نسخه ۱.۰.۰",
    settingsAboutSubtitle = "ساخته‌شده با Kotlin و Jetpack Compose برای دوستداران کمیک، مانگا و وب‌تون"
)

val EnStrings = AppStrings(
    language = AppLanguage.EN,
    appName = "Qabak",
    appTagline = "Comic & Manga Reader",
    langToggleBadge = "فا",

    navLibrary = "Library",
    navBookmarks = "Bookmarks",
    navSettings = "Settings",

    searchPlaceholder = "Search title, author, or genre...",
    continueReading = "Continue Reading",
    resumeButton = "Resume",
    startReading = "Start Reading",
    readAgain = "Read Again",
    importComic = "Import",
    shelfSectionTitle = "Bookshelf",
    filterAll = "All",
    filterReading = "Reading",
    filterCompleted = "Completed",
    filterFavorites = "Favorites",
    filterImported = "Imported",
    sortLabel = "Sort",
    sortRecent = "Last Read",
    sortTitle = "Title A–Z",
    sortProgress = "Progress",
    sortAdded = "Recently Added",
    emptyLibraryTitle = "Your bookshelf is empty",
    emptyLibrarySubtitle = "Import CBZ, CBR, PDF, or image folders from your device—or restore bundled comics in Settings.",
    emptyFilterTitle = "No matching comics",
    emptyFilterSubtitle = "Try switching filters or clearing your search query.",
    originalBadge = "ORIG",
    completedBadge = "Done",
    newBadge = "NEW",
    importingInProgress = "Importing comic into your shelf...",
    importSuccess = "Added to your library",
    importErrorGeneric = "Could not open this file. Please check that it is a valid comic.",
    importErrorRar5 = "This archive uses RAR5 compression. Please convert it to CBZ/ZIP or PDF.",
    importErrorEmpty = "No readable comic pages were found in the selected source.",

    importSheetTitle = "Import to Bookshelf",
    importSheetSubtitle = "Open comic archives, PDF graphic novels, or image folders from your device",
    importFileTitle = "Comic File (CBZ / CBR / PDF)",
    importFileDesc = "Supports CBZ/ZIP & CBR archives (with ComicInfo.xml) and PDF books",
    importFolderTitle = "Image Folder",
    importFolderDesc = "Reads a folder of pages in smart natural page order",
    importImagesTitle = "Create Comic from Images",
    importImagesDesc = "Pick multiple gallery images and bind them into one issue",
    supportedFormatsHint = "Supported formats: CBZ • ZIP • CBR • PDF • JPG • PNG • WEBP",
    imageCollectionDialogTitle = "Name Your Comic",
    imageCollectionNameLabel = "Comic title",
    imageCollectionDefaultName = "My Comic",
    confirmAction = "Create",
    cancelAction = "Cancel",

    backAction = "Back",
    favoriteAction = "Favorite",
    unfavoriteAction = "Favorited",
    markCompleted = "Mark Read",
    markUnread = "Reset Progress",
    shareCbzAction = "Share CBZ",
    deleteAction = "Delete",
    deleteDialogTitle = "Remove from library?",
    deleteDialogBody = "This comic and its bookmarks will be deleted. Bundled originals can always be restored from Settings.",
    synopsisTitle = "Synopsis",
    noSynopsis = "No synopsis available for this comic.",
    readingModeTitle = "Reading Mode",
    pagesPreviewTitle = "Pages",
    comicBookmarksTitle = "Bookmarks in This Issue",
    unknownAuthor = "Local Import",
    exportingComic = "Preparing CBZ archive for sharing...",

    modePagedRtl = "Paged Right-to-Left (Persian / Manga)",
    modePagedLtr = "Paged Left-to-Right (Western)",
    modeWebtoon = "Continuous Vertical (Webtoon)",
    modeGuidedPanel = "Smart Panel-by-Panel",
    modeShortRtl = "RTL",
    modeShortLtr = "LTR",
    modeShortWebtoon = "Webtoon",
    modeShortPanel = "Panels",
    fitWidth = "Fit Width",
    fitPage = "Fit Page",
    fitHeight = "Fit Height",
    filterNone = "Original",
    filterSepia = "Sepia",
    filterGrayscale = "Manga B&W",
    filterContrast = "Vivid Ink",
    bgBlack = "Dark",
    bgSepia = "Paper",
    bgWhite = "Light",
    dialogueTitle = "Sample Comic Dialogue",
    dialogueMatchApp = "Match App",
    dialogueFa = "فارسی",
    dialogueEn = "English",
    dialogueHidden = "Art Only",
    readerSettingsTitle = "Reader Settings",
    pageFitTitle = "Page Scale",
    colorFilterTitle = "Color Filter",
    backgroundTitle = "Canvas Background",
    brightnessTitle = "Brightness",
    brightnessAuto = "Auto",
    nightLightTitle = "Warm Eye-Comfort Tint",
    bookmarkAdded = "Page bookmarked",
    bookmarkRemoved = "Bookmark removed",
    addBookmarkNote = "Add Bookmark Note",
    editBookmarkNote = "Edit Bookmark Note",
    bookmarkNoteHint = "e.g. Favorite panel, key plot twist...",
    saveAction = "Save",
    pageListTitle = "Jump to Page",
    previousPage = "Previous page",
    nextPage = "Next page",
    endOfComicToast = "You reached the end of this issue!",
    panelIndicatorLabel = "Guided Panel View",
    loadingPage = "Rendering page...",
    pageLoadError = "Could not render page",

    statsHeaderTitle = "Reading Overview",
    statBooks = "Comics",
    statCompleted = "Finished",
    statPagesRead = "Pages Read",
    statBookmarks = "Bookmarks",
    emptyBookmarksTitle = "No bookmarks yet",
    emptyBookmarksSubtitle = "Tap the bookmark icon in the reader's top bar to save favorite scenes and notes here.",
    openPageAction = "Jump to page",

    settingsAppearanceSection = "Appearance & Language",
    settingsLanguageLabel = "App Language",
    settingsThemeLabel = "Color Theme",
    themeDark = "Ink Dark",
    themeLight = "Warm Paper",
    themeAmoled = "Pure OLED",
    settingsReaderSection = "Reader Preferences",
    settingsDefaultModeLabel = "Default Reading Mode",
    settingsVolumeKeysLabel = "Volume Key Page Turn",
    settingsVolumeKeysDesc = "Turn pages or step through panels using hardware volume buttons",
    settingsKeepScreenOnLabel = "Keep Screen Awake",
    settingsKeepScreenOnDesc = "Prevent display sleep while actively reading a comic",
    settingsPageOverlayLabel = "Corner Page Badge",
    settingsPageOverlayDesc = "Show subtle page counter while reader controls are hidden",
    settingsStorageSection = "Storage & Library",
    settingsStorageUsedLabel = "Imported files & thumbnails",
    settingsClearCacheAction = "Clear Temp Cache",
    settingsCacheClearedToast = "Temporary cache cleared",
    settingsRestoreSamplesLabel = "Restore Sample Comics",
    settingsRestoreSamplesDesc = "Re-add Qabak's built-in illustrated comics if removed",
    settingsSamplesRestoredToast = "Sample comics restored to your shelf",
    settingsSamplesAlreadyPresent = "All sample comics are already in your library",
    settingsAboutTitle = "Qabak Comics • v1.0.0",
    settingsAboutSubtitle = "Crafted natively with Kotlin & Jetpack Compose for comic, manga & webtoon lovers"
)

fun stringsFor(language: AppLanguage): AppStrings =
    if (language == AppLanguage.FA) FaStrings else EnStrings

fun localizeDigits(input: String, language: AppLanguage): String {
    if (language != AppLanguage.FA) return input
    val out = StringBuilder(input.length)
    for (ch in input) {
        when (ch) {
            in '0'..'9' -> out.append(('۰'.code + (ch - '0')).toChar())
            '.' -> out.append('٫')
            else -> out.append(ch)
        }
    }
    return out.toString()
}

fun formatStorageSize(bytes: Long, language: AppLanguage): String {
    val kb = bytes / 1024.0
    val mb = kb / 1024.0
    val raw = when {
        bytes < 1024L -> if (language == AppLanguage.FA) "۰ کیلوبایت" else "0 KB"
        mb < 1.0 -> {
            val v = String.format(Locale.US, "%.0f", kb)
            if (language == AppLanguage.FA) "${localizeDigits(v, language)} کیلوبایت" else "$v KB"
        }
        else -> {
            val v = String.format(Locale.US, "%.1f", mb)
            if (language == AppLanguage.FA) "${localizeDigits(v, language)} مگابایت" else "$v MB"
        }
    }
    return raw
}

val LocalAppStrings = compositionLocalOf { FaStrings }
