package com.qabak.comics.ui.navigation

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoStories
import androidx.compose.material.icons.outlined.Bookmarks
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.rounded.AutoStories
import androidx.compose.material.icons.rounded.Bookmarks
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.qabak.comics.model.ReadingMode
import com.qabak.comics.ui.MainViewModel
import com.qabak.comics.ui.UiEvent
import com.qabak.comics.ui.components.ImageCollectionTitleDialog
import com.qabak.comics.ui.components.ImportComicBottomSheet
import com.qabak.comics.ui.i18n.LocalAppStrings
import com.qabak.comics.ui.screens.bookmarks.BookmarksScreen
import com.qabak.comics.ui.screens.detail.ComicDetailScreen
import com.qabak.comics.ui.screens.library.LibraryScreen
import com.qabak.comics.ui.screens.reader.ReaderScreen
import com.qabak.comics.ui.screens.settings.SettingsScreen
import com.qabak.comics.ui.theme.QabakTheme
import kotlinx.coroutines.flow.collectLatest

private object Routes {
    const val LIBRARY = "library"
    const val BOOKMARKS = "bookmarks"
    const val SETTINGS = "settings"
    const val DETAIL = "detail/{comicId}"
    const val READER = "reader/{comicId}?page={page}&mode={mode}"

    fun detail(comicId: String) = "detail/${Uri.encode(comicId)}"
    fun reader(comicId: String, page: Int, mode: ReadingMode? = null): String {
        val m = mode?.name.orEmpty()
        return "reader/${Uri.encode(comicId)}?page=$page&mode=$m"
    }
}

@Composable
fun QabakAppRoot(viewModel: MainViewModel) {
    val settings by viewModel.settings.collectAsStateWithLifecycle()
    val comics by viewModel.comics.collectAsStateWithLifecycle()
    val bookmarks by viewModel.allBookmarks.collectAsStateWithLifecycle()
    val stats by viewModel.readingStats.collectAsStateWithLifecycle()
    val isImporting by viewModel.isImporting.collectAsStateWithLifecycle()
    val storageBytes by viewModel.storageBytes.collectAsStateWithLifecycle()

    QabakTheme(
        themeMode = settings.themeMode,
        language = settings.language
    ) {
        val strings = LocalAppStrings.current
        val context = LocalContext.current
        val navController = rememberNavController()
        val snackbarHostState = remember { SnackbarHostState() }

        var showImportSheet by rememberSaveable { mutableStateOf(false) }
        var pendingImageUris by remember { mutableStateOf<List<Uri>?>(null) }

        // SAF File Pickers (Zero storage permission prompts needed on Android 8–16!)
        val filePickerLauncher = rememberLauncherForActivityResult(
            contract = ActivityResultContracts.OpenDocument()
        ) { uri ->
            if (uri != null) {
                viewModel.importComicFile(uri)
            }
        }

        val folderPickerLauncher = rememberLauncherForActivityResult(
            contract = ActivityResultContracts.OpenDocumentTree()
        ) { treeUri ->
            if (treeUri != null) {
                viewModel.importFolder(treeUri)
            }
        }

        val imagesPickerLauncher = rememberLauncherForActivityResult(
            contract = ActivityResultContracts.OpenMultipleDocuments()
        ) { uris ->
            if (uris.isNotEmpty()) {
                pendingImageUris = uris
            }
        }

        LaunchedEffect(viewModel.events) {
            viewModel.events.collectLatest { event ->
                when (event) {
                    is UiEvent.ShowSnackbar -> snackbarHostState.showSnackbar(event.message)
                    is UiEvent.OpenComicReader -> {
                        navController.navigate(Routes.reader(event.comicId, event.page))
                    }
                }
            }
        }

        val navBackStackEntry by navController.currentBackStackEntryAsState()
        val currentRoute = navBackStackEntry?.destination?.route
        val showBottomBar = currentRoute in setOf(Routes.LIBRARY, Routes.BOOKMARKS, Routes.SETTINGS)

        LaunchedEffect(currentRoute) {
            viewModel.setReaderActive(currentRoute == Routes.READER)
            if (currentRoute == Routes.SETTINGS) {
                viewModel.refreshStorageUsage()
            }
        }

        Scaffold(
            containerColor = MaterialTheme.colorScheme.background,
            snackbarHost = { SnackbarHost(snackbarHostState) },
            bottomBar = {
                if (showBottomBar) {
                    NavigationBar(
                        containerColor = MaterialTheme.colorScheme.surface,
                        tonalElevation = 4.dp
                    ) {
                        val tabs = listOf(
                            Triple(Routes.LIBRARY, strings.navLibrary, Icons.Rounded.AutoStories to Icons.Outlined.AutoStories),
                            Triple(Routes.BOOKMARKS, strings.navBookmarks, Icons.Rounded.Bookmarks to Icons.Outlined.Bookmarks),
                            Triple(Routes.SETTINGS, strings.navSettings, Icons.Rounded.Settings to Icons.Outlined.Settings)
                        )
                        tabs.forEach { (route, label, iconPair) ->
                            val selected = currentRoute == route
                            NavigationBarItem(
                                selected = selected,
                                onClick = {
                                    if (!selected) {
                                        navController.navigate(route) {
                                            popUpTo(navController.graph.findStartDestination().id) {
                                                saveState = true
                                            }
                                            launchSingleTop = true
                                            restoreState = true
                                        }
                                    }
                                },
                                icon = {
                                    Icon(
                                        imageVector = if (selected) iconPair.first else iconPair.second,
                                        contentDescription = label
                                    )
                                },
                                label = {
                                    Text(
                                        text = label,
                                        style = MaterialTheme.typography.labelMedium
                                    )
                                },
                                colors = NavigationBarItemDefaults.colors(
                                    selectedIconColor = MaterialTheme.colorScheme.onPrimary,
                                    selectedTextColor = MaterialTheme.colorScheme.primary,
                                    indicatorColor = MaterialTheme.colorScheme.primary,
                                    unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                    unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            )
                        }
                    }
                }
            }
        ) { innerPadding ->
            NavHost(
                navController = navController,
                startDestination = Routes.LIBRARY,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(bottom = if (showBottomBar) innerPadding.calculateBottomPadding() else 0.dp)
            ) {
                composable(Routes.LIBRARY) {
                    LibraryScreen(
                        comics = comics,
                        gridColumnsPref = settings.gridColumns,
                        isImporting = isImporting,
                        loadCover = { viewModel.loadCover(it) },
                        onToggleLanguage = { viewModel.toggleLanguage() },
                        onToggleGridMode = { viewModel.toggleGridColumns() },
                        onOpenImportSheet = { showImportSheet = true },
                        onOpenComicDetail = { comic -> navController.navigate(Routes.detail(comic.id)) },
                        onOpenComicReader = { comic, page ->
                            navController.navigate(Routes.reader(comic.id, page, comic.preferredMode))
                        },
                        onToggleFavorite = { comic -> viewModel.toggleFavorite(comic.id) }
                    )
                }

                composable(Routes.BOOKMARKS) {
                    BookmarksScreen(
                        stats = stats,
                        bookmarks = bookmarks,
                        loadBookmarkThumb = { viewModel.loadBookmarkThumb(it) },
                        onOpenBookmark = { bm ->
                            navController.navigate(Routes.reader(bm.comicId, bm.pageIndex))
                        },
                        onUpdateNote = { bm, note ->
                            viewModel.saveBookmarkNote(bm.comicId, bm.pageIndex, note)
                        },
                        onDeleteBookmark = { bm -> viewModel.deleteBookmark(bm.id) }
                    )
                }

                composable(Routes.SETTINGS) {
                    SettingsScreen(
                        settings = settings,
                        storageUsedBytes = storageBytes,
                        onSelectLanguage = { viewModel.setLanguage(it) },
                        onSelectTheme = { viewModel.setThemeMode(it) },
                        onSelectDefaultMode = { viewModel.setDefaultReadingMode(it) },
                        onSelectDialogueMode = { viewModel.setDialogueMode(it) },
                        onToggleVolumeKeys = { viewModel.setVolumeKeys(it) },
                        onToggleKeepScreenOn = { viewModel.setKeepScreenOn(it) },
                        onTogglePageOverlay = { viewModel.setShowPageOverlay(it) },
                        onClearCache = { viewModel.clearCache() },
                        onRestoreSamples = { viewModel.restoreSampleComics() }
                    )
                }

                composable(
                    route = Routes.DETAIL,
                    arguments = listOf(navArgument("comicId") { type = NavType.StringType })
                ) { entry ->
                    val comicId = entry.arguments?.getString("comicId").orEmpty()
                    val comicFlow = remember(comicId) { viewModel.observeComic(comicId) }
                    val bmFlow = remember(comicId) { viewModel.observeComicBookmarks(comicId) }
                    val comic by comicFlow.collectAsStateWithLifecycle(initialValue = null)
                    val comicBookmarks by bmFlow.collectAsStateWithLifecycle(initialValue = emptyList())

                    val loadedComic = comic
                    if (loadedComic != null) {
                        val thumbSource = remember(loadedComic.id, loadedComic.sourcePath) {
                            viewModel.openPageSource(loadedComic).getOrNull()
                        }
                        DisposableEffect(thumbSource) {
                            onDispose { thumbSource?.close() }
                        }

                        ComicDetailScreen(
                            comic = loadedComic,
                            bookmarks = comicBookmarks,
                            loadCover = { viewModel.loadCover(it) },
                            loadPageThumb = { idx ->
                                thumbSource?.renderPage(idx, maxWidth = 300, maxHeight = 450)
                            },
                            onBack = { navController.popBackStack() },
                            onOpenReader = { page, mode ->
                                navController.navigate(Routes.reader(loadedComic.id, page, mode))
                            },
                            onToggleFavorite = { viewModel.toggleFavorite(loadedComic.id) },
                            onToggleCompleted = { viewModel.toggleCompleted(loadedComic.id) },
                            onSelectMode = { mode -> viewModel.setComicPreferredMode(loadedComic.id, mode) },
                            onShareCbz = { viewModel.shareComicAsCbz(context, loadedComic) },
                            onDeleteComic = {
                                viewModel.deleteComic(loadedComic)
                                navController.popBackStack()
                            }
                        )
                    } else {
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator()
                        }
                    }
                }

                composable(
                    route = Routes.READER,
                    arguments = listOf(
                        navArgument("comicId") { type = NavType.StringType },
                        navArgument("page") { type = NavType.IntType; defaultValue = 0 },
                        navArgument("mode") { type = NavType.StringType; defaultValue = "" }
                    )
                ) { entry ->
                    val comicId = entry.arguments?.getString("comicId").orEmpty()
                    val startPage = entry.arguments?.getInt("page") ?: 0
                    val modeArg = entry.arguments?.getString("mode").orEmpty()
                    val comicFlow = remember(comicId) { viewModel.observeComic(comicId) }
                    val bmFlow = remember(comicId) { viewModel.observeComicBookmarks(comicId) }
                    val comic by comicFlow.collectAsStateWithLifecycle(initialValue = null)
                    val comicBookmarks by bmFlow.collectAsStateWithLifecycle(initialValue = emptyList())

                    val loadedComic = comic
                    if (loadedComic != null) {
                        val sourceResult = remember(loadedComic.id, loadedComic.sourcePath) {
                            viewModel.openPageSource(loadedComic)
                        }
                        val source = sourceResult.getOrNull()
                        DisposableEffect(source) {
                            onDispose { source?.close() }
                        }

                        if (source != null) {
                            val resolvedMode = remember(modeArg, loadedComic.id) {
                                runCatching { ReadingMode.valueOf(modeArg) }
                                    .getOrDefault(loadedComic.preferredMode)
                            }
                            val bmPages = remember(comicBookmarks) {
                                comicBookmarks.map { it.pageIndex }.toSet()
                            }
                            val bmNotes = remember(comicBookmarks) {
                                comicBookmarks.associate { it.pageIndex to it.note }
                            }

                            ReaderScreen(
                                comic = loadedComic,
                                source = source,
                                initialPage = startPage,
                                initialMode = resolvedMode,
                                settings = settings,
                                bookmarkedPages = bmPages,
                                bookmarkNotes = bmNotes,
                                volumeStepEvents = viewModel.volumeStepEvents,
                                onBack = { navController.popBackStack() },
                                onPageChanged = { p -> viewModel.updateReadingProgress(loadedComic.id, p) },
                                onModeChanged = { m -> viewModel.setComicPreferredMode(loadedComic.id, m) },
                                onPageFitChanged = { f -> viewModel.setPageFitMode(f) },
                                onColorFilterChanged = { cf -> viewModel.setColorFilter(cf) },
                                onBackgroundChanged = { bg -> viewModel.setReaderBackground(bg) },
                                onDialogueModeChanged = { dm -> viewModel.setDialogueMode(dm) },
                                onBrightnessChanged = { br -> viewModel.setBrightnessOverride(br) },
                                onNightWarmthChanged = { nw -> viewModel.setNightWarmth(nw) },
                                onToggleVolumeKeys = { vk -> viewModel.setVolumeKeys(vk) },
                                onToggleBookmark = { p -> viewModel.toggleBookmark(loadedComic.id, p) },
                                onSaveBookmarkNote = { p, note ->
                                    viewModel.saveBookmarkNote(loadedComic.id, p, note)
                                },
                                onNoticeMessage = { msg -> viewModel.postNotice(msg) }
                            )
                        } else {
                            LaunchedEffect(Unit) {
                                viewModel.postNotice(strings.importErrorGeneric)
                                navController.popBackStack()
                            }
                        }
                    } else {
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator()
                        }
                    }
                }
            }
        }

        if (showImportSheet) {
            ImportComicBottomSheet(
                onDismiss = { showImportSheet = false },
                onPickComicFile = {
                    // Use */* so Android's SAF enables .cbz and .cbr files even when OEM file managers omit custom MIME types
                    filePickerLauncher.launch(arrayOf("*/*"))
                },
                onPickFolder = {
                    folderPickerLauncher.launch(null)
                },
                onPickImages = {
                    imagesPickerLauncher.launch(arrayOf("image/*"))
                }
            )
        }

        pendingImageUris?.let { uris ->
            ImageCollectionTitleDialog(
                defaultTitle = strings.imageCollectionDefaultName,
                onDismiss = { pendingImageUris = null },
                onConfirm = { customName ->
                    val list = uris
                    pendingImageUris = null
                    viewModel.importImageCollection(list, customName)
                }
            )
        }
    }
}
