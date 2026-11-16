package com.qabak.comics.ui.screens.reader

import android.app.Activity
import android.graphics.Bitmap
import android.view.WindowManager
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Bookmark
import androidx.compose.material.icons.rounded.BookmarkBorder
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Collections
import androidx.compose.material.icons.rounded.EditNote
import androidx.compose.material.icons.rounded.Translate
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChanged
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.qabak.comics.data.parser.ComicPageSource
import com.qabak.comics.model.AppLanguage
import com.qabak.comics.model.ComicBook
import com.qabak.comics.model.DialogueDisplayMode
import com.qabak.comics.model.PageFitMode
import com.qabak.comics.model.PanelRect
import com.qabak.comics.model.ReaderBackground
import com.qabak.comics.model.ReaderColorFilter
import com.qabak.comics.model.ReadingMode
import com.qabak.comics.model.UserSettings
import com.qabak.comics.ui.components.ComicPageArtwork
import com.qabak.comics.ui.components.ZoomableComicPage
import com.qabak.comics.ui.components.buildReaderColorFilter
import com.qabak.comics.ui.components.readerBackgroundColor
import com.qabak.comics.ui.components.resolveDialogueLanguage
import com.qabak.comics.ui.i18n.LocalAppStrings
import com.qabak.comics.ui.theme.ComicAmber
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

@Composable
fun ReaderScreen(
    comic: ComicBook,
    source: ComicPageSource,
    initialPage: Int,
    initialMode: ReadingMode,
    settings: UserSettings,
    bookmarkedPages: Set<Int>,
    bookmarkNotes: Map<Int, String>,
    volumeStepEvents: Flow<Int> = emptyFlow(),
    initialHudVisible: Boolean = true,
    onBack: () -> Unit,
    onPageChanged: (Int) -> Unit,
    onModeChanged: (ReadingMode) -> Unit,
    onPageFitChanged: (PageFitMode) -> Unit,
    onColorFilterChanged: (ReaderColorFilter) -> Unit,
    onBackgroundChanged: (ReaderBackground) -> Unit,
    onDialogueModeChanged: (DialogueDisplayMode) -> Unit,
    onBrightnessChanged: (Float) -> Unit,
    onNightWarmthChanged: (Float) -> Unit,
    onToggleVolumeKeys: (Boolean) -> Unit,
    onToggleBookmark: (Int) -> Unit,
    onSaveBookmarkNote: (Int, String) -> Unit,
    onNoticeMessage: (String) -> Unit = {},
    modifier: Modifier = Modifier
) {
    val strings = LocalAppStrings.current
    val scope = rememberCoroutineScope()
    val totalPages = source.pageCount.coerceAtLeast(1)
    val safeStartPage = initialPage.coerceIn(0, totalPages - 1)

    var readingMode by rememberSaveable(comic.id) { mutableStateOf(initialMode) }
    var currentPage by rememberSaveable(comic.id) { mutableIntStateOf(safeStartPage) }
    var hudVisible by rememberSaveable { mutableStateOf(initialHudVisible) }
    var showSettingsSheet by remember { mutableStateOf(false) }
    var showThumbStrip by remember { mutableStateOf(false) }
    var showNoteDialog by remember { mutableStateOf(false) }

    // Guided panel state
    var currentPanels by remember { mutableStateOf<List<PanelRect>>(emptyList()) }
    var currentPanelIndex by rememberSaveable { mutableIntStateOf(0) }
    var pendingLastPanelOnArrive by remember { mutableStateOf(false) }

    val pagerState = rememberPagerState(initialPage = safeStartPage) { totalPages }
    val webtoonListState = rememberLazyListState(initialFirstVisibleItemIndex = safeStartPage)

    val colorFilter = remember(settings.colorFilter) { buildReaderColorFilter(settings.colorFilter) }
    val bgColor = remember(settings.readerBackground) { readerBackgroundColor(settings.readerBackground) }
    val dialogueLang = remember(settings.dialogueMode, strings.language) {
        resolveDialogueLanguage(settings.dialogueMode, strings.language)
    }

    // Window effects: Keep Screen On, Brightness Override & Immersive System Bars
    val context = LocalContext.current
    val view = LocalView.current
    DisposableEffect(settings.keepScreenOn) {
        val window = (context as? Activity)?.window
        if (settings.keepScreenOn) {
            window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        onDispose {
            window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    DisposableEffect(settings.brightnessOverride) {
        val window = (context as? Activity)?.window
        if (window != null) {
            val attrs = window.attributes
            attrs.screenBrightness = if (settings.brightnessOverride in 0.05f..1f) {
                settings.brightnessOverride
            } else {
                WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            }
            window.attributes = attrs
        }
        onDispose {
            val w = (context as? Activity)?.window
            if (w != null) {
                val attrs = w.attributes
                attrs.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                w.attributes = attrs
            }
        }
    }

    DisposableEffect(hudVisible) {
        val window = (context as? Activity)?.window
        if (window != null && !view.isInEditMode) {
            runCatching {
                val controller = WindowCompat.getInsetsController(window, view)
                controller.systemBarsBehavior =
                    WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                if (hudVisible) {
                    controller.show(WindowInsetsCompat.Type.systemBars())
                } else {
                    controller.hide(WindowInsetsCompat.Type.systemBars())
                }
            }
        }
        onDispose {
            val w = (context as? Activity)?.window
            if (w != null && !view.isInEditMode) {
                runCatching {
                    WindowCompat.getInsetsController(w, view)
                        .show(WindowInsetsCompat.Type.systemBars())
                }
            }
        }
    }

    // Persist reading progress whenever currentPage changes
    LaunchedEffect(currentPage) {
        onPageChanged(currentPage)
        // Warm cache for neighbor pages in background
        launch {
            if (currentPage + 1 < totalPages) source.renderPage(currentPage + 1)
            if (currentPage - 1 >= 0) source.renderPage(currentPage - 1)
        }
    }

    // Track HorizontalPager page changes when in paged modes
    LaunchedEffect(readingMode, pagerState) {
        if (readingMode == ReadingMode.PAGED_RTL || readingMode == ReadingMode.PAGED_LTR) {
            if (pagerState.currentPage != currentPage) {
                pagerState.scrollToPage(currentPage)
            }
            snapshotFlow { pagerState.settledPage }
                .distinctUntilChanged()
                .collect { page ->
                    currentPage = page
                }
        }
    }

    // Track Webtoon scroll position when in WEBTOON mode
    LaunchedEffect(readingMode, webtoonListState) {
        if (readingMode == ReadingMode.WEBTOON) {
            webtoonListState.scrollToItem(currentPage)
            snapshotFlow { webtoonListState.firstVisibleItemIndex }
                .distinctUntilChanged()
                .collect { idx ->
                    if (idx in 0 until totalPages) {
                        currentPage = idx
                    }
                }
        }
    }

    // Load panel rectangles when in GUIDED_PANEL mode
    LaunchedEffect(readingMode, currentPage, strings.language) {
        if (readingMode == ReadingMode.GUIDED_PANEL) {
            val panels = source.getPanels(currentPage, rtlOrder = strings.language.isRtl)
            currentPanels = panels
            currentPanelIndex = if (pendingLastPanelOnArrive) {
                pendingLastPanelOnArrive = false
                (panels.size - 1).coerceAtLeast(0)
            } else {
                0
            }
        } else {
            currentPanels = emptyList()
            currentPanelIndex = 0
        }
    }

    fun jumpToPage(target: Int, animated: Boolean = true) {
        val clamped = target.coerceIn(0, totalPages - 1)
        currentPage = clamped
        currentPanelIndex = 0
        scope.launch {
            when (readingMode) {
                ReadingMode.PAGED_RTL, ReadingMode.PAGED_LTR -> {
                    if (animated) pagerState.animateScrollToPage(clamped)
                    else pagerState.scrollToPage(clamped)
                }
                ReadingMode.WEBTOON -> {
                    if (animated) webtoonListState.animateScrollToItem(clamped)
                    else webtoonListState.scrollToItem(clamped)
                }
                ReadingMode.GUIDED_PANEL -> Unit
            }
        }
    }

    fun stepForward() {
        if (readingMode == ReadingMode.GUIDED_PANEL && currentPanels.isNotEmpty()) {
            if (currentPanelIndex < currentPanels.lastIndex) {
                currentPanelIndex++
                return
            }
        }
        if (currentPage < totalPages - 1) {
            pendingLastPanelOnArrive = false
            jumpToPage(currentPage + 1)
        } else {
            onNoticeMessage(strings.endOfComicToast)
        }
    }

    fun stepBackward() {
        if (readingMode == ReadingMode.GUIDED_PANEL && currentPanels.isNotEmpty()) {
            if (currentPanelIndex > 0) {
                currentPanelIndex--
                return
            }
            if (currentPage > 0) {
                pendingLastPanelOnArrive = true
                currentPage -= 1
                return
            }
        }
        if (currentPage > 0) {
            jumpToPage(currentPage - 1)
        }
    }

    // Hardware Volume Up (-1) / Volume Down (+1) navigation
    LaunchedEffect(volumeStepEvents, settings.volumeKeysNavigation) {
        volumeStepEvents.collectLatest { delta ->
            if (settings.volumeKeysNavigation) {
                if (delta > 0) stepForward() else stepBackward()
            }
        }
    }

    val isCurrentBookmarked = currentPage in bookmarkedPages
    val isRtlReaderFlow = when (readingMode) {
        ReadingMode.PAGED_RTL -> true
        ReadingMode.PAGED_LTR -> false
        ReadingMode.WEBTOON, ReadingMode.GUIDED_PANEL -> strings.language.isRtl
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(bgColor)
    ) {
        // 1. Core Reading Canvas
        when (readingMode) {
            ReadingMode.PAGED_RTL, ReadingMode.PAGED_LTR -> {
                val pagerDir = if (readingMode == ReadingMode.PAGED_RTL) {
                    LayoutDirection.Rtl
                } else {
                    LayoutDirection.Ltr
                }
                CompositionLocalProvider(LocalLayoutDirection provides pagerDir) {
                    HorizontalPager(
                        state = pagerState,
                        beyondViewportPageCount = 1,
                        key = { it },
                        modifier = Modifier.fillMaxSize()
                    ) { pageIdx ->
                        PagedComicPageSlot(
                            source = source,
                            pageIndex = pageIdx,
                            dialogueLanguage = dialogueLang,
                            pageFitMode = settings.pageFitMode,
                            colorFilter = colorFilter,
                            backgroundColor = bgColor,
                            isRtlNavigation = readingMode == ReadingMode.PAGED_RTL,
                            guidedPanel = null,
                            onCenterTap = {
                                hudVisible = !hudVisible
                                if (!hudVisible) showThumbStrip = false
                            },
                            onNextTap = { stepForward() },
                            onPrevTap = { stepBackward() }
                        )
                    }
                }
            }

            ReadingMode.GUIDED_PANEL -> {
                val activePanel = currentPanels.getOrNull(currentPanelIndex)
                PagedComicPageSlot(
                    source = source,
                    pageIndex = currentPage,
                    dialogueLanguage = dialogueLang,
                    pageFitMode = PageFitMode.FIT_PAGE,
                    colorFilter = colorFilter,
                    backgroundColor = bgColor,
                    isRtlNavigation = strings.language.isRtl,
                    guidedPanel = activePanel,
                    onCenterTap = {
                        hudVisible = !hudVisible
                        if (!hudVisible) showThumbStrip = false
                    },
                    onNextTap = { stepForward() },
                    onPrevTap = { stepBackward() }
                )
            }

            ReadingMode.WEBTOON -> {
                WebtoonStreamView(
                    source = source,
                    totalPages = totalPages,
                    listState = webtoonListState,
                    dialogueLanguage = dialogueLang,
                    colorFilter = colorFilter,
                    backgroundColor = bgColor,
                    onToggleHud = {
                        hudVisible = !hudVisible
                        if (!hudVisible) showThumbStrip = false
                    }
                )
            }
        }

        // 2. Warm Night-Light Eye Comfort Tint Overlay (non-interactive)
        if (settings.nightWarmth > 0.01f) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xFFFF8800).copy(alpha = settings.nightWarmth.coerceIn(0f, 0.45f)))
            )
        }

        // 3. Minimal Corner Page / Panel Pill when HUD is hidden
        AnimatedVisibility(
            visible = !hudVisible && settings.showPageNumberOverlay,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(bottom = 12.dp)
        ) {
            Surface(
                shape = CircleShape,
                color = Color(0xB3090C14),
                border = BorderStroke(0.8.dp, Color.White.copy(alpha = 0.16f))
            ) {
                val badge = buildString {
                    append(strings.compactPageFraction(currentPage, totalPages))
                    if (readingMode == ReadingMode.GUIDED_PANEL && currentPanels.size > 1) {
                        append("  •  ")
                        append(strings.panelOfTotal(currentPanelIndex, currentPanels.size))
                    }
                }
                Text(
                    text = badge,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White.copy(alpha = 0.9f),
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 5.dp)
                )
            }
        }

        // 4. Top Reader Control Bar
        AnimatedVisibility(
            visible = hudVisible,
            enter = slideInVertically { -it } + fadeIn(),
            exit = slideOutVertically { -it } + fadeOut(),
            modifier = Modifier.align(Alignment.TopCenter)
        ) {
            Surface(
                color = Color(0xEB0C1018),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .statusBarsPadding()
                        .padding(horizontal = 8.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Rounded.ArrowBack,
                            contentDescription = strings.backAction,
                            tint = Color.White
                        )
                    }

                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .padding(horizontal = 4.dp)
                    ) {
                        Text(
                            text = comic.localizedTitle(strings.language),
                            style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                            color = Color.White,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        val pageTitle = source.getPageTitle(currentPage, strings.language == AppLanguage.FA)
                        val subtitle = buildString {
                            append(pageTitle ?: strings.pageOfTotal(currentPage, totalPages))
                            if (readingMode == ReadingMode.GUIDED_PANEL && currentPanels.isNotEmpty()) {
                                append(" • ")
                                append(strings.panelOfTotal(currentPanelIndex, currentPanels.size))
                            }
                        }
                        Text(
                            text = subtitle,
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.White.copy(alpha = 0.72f),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }

                    // Quick bilingual speech-bubble language toggle for comics with dialogue overlays
                    if (source.hasOverlayDialogue) {
                        Surface(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .clickable {
                                    val next = when (settings.dialogueMode) {
                                        DialogueDisplayMode.MATCH_APP -> {
                                            if (strings.language == AppLanguage.FA) DialogueDisplayMode.EN
                                            else DialogueDisplayMode.FA
                                        }
                                        DialogueDisplayMode.FA -> DialogueDisplayMode.EN
                                        DialogueDisplayMode.EN -> DialogueDisplayMode.HIDDEN
                                        DialogueDisplayMode.HIDDEN -> DialogueDisplayMode.FA
                                    }
                                    onDialogueModeChanged(next)
                                },
                            shape = RoundedCornerShape(8.dp),
                            color = Color.White.copy(alpha = 0.12f),
                            border = BorderStroke(1.dp, ComicAmber.copy(alpha = 0.6f))
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Rounded.Translate,
                                    contentDescription = strings.dialogueTitle,
                                    tint = ComicAmber,
                                    modifier = Modifier.size(14.dp)
                                )
                                val shortTag = when (dialogueLang) {
                                    AppLanguage.FA -> "فا"
                                    AppLanguage.EN -> "EN"
                                    null -> "—"
                                }
                                Text(
                                    text = shortTag,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = Color.White
                                )
                            }
                        }
                    }

                    // Bookmark toggle
                    IconButton(
                        onClick = {
                            onToggleBookmark(currentPage)
                            onNoticeMessage(
                                if (isCurrentBookmarked) strings.bookmarkRemoved else strings.bookmarkAdded
                            )
                        }
                    ) {
                        Icon(
                            imageVector = if (isCurrentBookmarked) {
                                Icons.Rounded.Bookmark
                            } else {
                                Icons.Rounded.BookmarkBorder
                            },
                            contentDescription = strings.navBookmarks,
                            tint = if (isCurrentBookmarked) ComicAmber else Color.White
                        )
                    }

                    // Add/Edit Bookmark Note
                    IconButton(onClick = { showNoteDialog = true }) {
                        Icon(
                            imageVector = Icons.Rounded.EditNote,
                            contentDescription = strings.addBookmarkNote,
                            tint = if (bookmarkNotes[currentPage]?.isNotBlank() == true) ComicAmber else Color.White
                        )
                    }

                    // Reader Settings Sheet
                    IconButton(onClick = { showSettingsSheet = true }) {
                        Icon(
                            imageVector = Icons.Rounded.Tune,
                            contentDescription = strings.readerSettingsTitle,
                            tint = Color.White
                        )
                    }
                }
            }
        }

        // 5. Bottom Reader Control Bar + Quick Thumbnail Filmstrip
        AnimatedVisibility(
            visible = hudVisible,
            enter = slideInVertically { it } + fadeIn(),
            exit = slideOutVertically { it } + fadeOut(),
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                // Expandable page filmstrip
                AnimatedVisibility(visible = showThumbStrip) {
                    Surface(
                        color = Color(0xEB0E131D),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 14.dp, vertical = 10.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            items(totalPages) { idx ->
                                ReaderMiniThumb(
                                    source = source,
                                    pageIndex = idx,
                                    isSelected = idx == currentPage,
                                    isBookmarked = idx in bookmarkedPages,
                                    onClick = { jumpToPage(idx) }
                                )
                            }
                        }
                    }
                }

                Surface(
                    color = Color(0xF00C1018),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .navigationBarsPadding()
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        // Quick Reading Mode Switcher Row
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            ReadingMode.entries.forEach { mode ->
                                val selected = readingMode == mode
                                Surface(
                                    modifier = Modifier
                                        .weight(1f)
                                        .clip(RoundedCornerShape(9.dp))
                                        .clickable {
                                            readingMode = mode
                                            onModeChanged(mode)
                                        },
                                    shape = RoundedCornerShape(9.dp),
                                    color = if (selected) ComicAmber else Color.White.copy(alpha = 0.09f)
                                ) {
                                    Box(
                                        contentAlignment = Alignment.Center,
                                        modifier = Modifier.padding(vertical = 6.dp, horizontal = 4.dp)
                                    ) {
                                        Text(
                                            text = strings.modeShortLabel(mode),
                                            style = MaterialTheme.typography.labelSmall.copy(
                                                fontWeight = FontWeight.Bold
                                            ),
                                            color = if (selected) Color(0xFF14110A) else Color.White.copy(alpha = 0.85f),
                                            maxLines = 1,
                                            overflow = TextOverflow.Ellipsis
                                        )
                                    }
                                }
                            }
                        }

                        // Page Scrubber Row (respects active reading direction!)
                        val sliderDir = if (isRtlReaderFlow) LayoutDirection.Rtl else LayoutDirection.Ltr
                        CompositionLocalProvider(LocalLayoutDirection provides sliderDir) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                IconButton(
                                    onClick = { stepBackward() },
                                    modifier = Modifier.size(36.dp)
                                ) {
                                    Icon(
                                        imageVector = if (isRtlReaderFlow) {
                                            Icons.Rounded.ChevronRight
                                        } else {
                                            Icons.Rounded.ChevronLeft
                                        },
                                        contentDescription = strings.previousPage,
                                        tint = Color.White
                                    )
                                }

                                if (totalPages > 1) {
                                    Slider(
                                        value = currentPage.toFloat(),
                                        onValueChange = { raw ->
                                            jumpToPage(raw.roundToInt(), animated = false)
                                        },
                                        valueRange = 0f..(totalPages - 1).toFloat(),
                                        steps = (totalPages - 2).coerceIn(0, 60),
                                        colors = SliderDefaults.colors(
                                            thumbColor = ComicAmber,
                                            activeTrackColor = ComicAmber,
                                            inactiveTrackColor = Color.White.copy(alpha = 0.22f)
                                        ),
                                        modifier = Modifier.weight(1f)
                                    )
                                } else {
                                    Spacer(Modifier.weight(1f))
                                }

                                IconButton(
                                    onClick = { stepForward() },
                                    modifier = Modifier.size(36.dp)
                                ) {
                                    Icon(
                                        imageVector = if (isRtlReaderFlow) {
                                            Icons.Rounded.ChevronLeft
                                        } else {
                                            Icons.Rounded.ChevronRight
                                        },
                                        contentDescription = strings.nextPage,
                                        tint = Color.White
                                    )
                                }

                                Text(
                                    text = strings.compactPageFraction(currentPage, totalPages),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = Color.White,
                                    modifier = Modifier.padding(horizontal = 4.dp)
                                )

                                IconButton(
                                    onClick = { showThumbStrip = !showThumbStrip },
                                    modifier = Modifier.size(36.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.Rounded.Collections,
                                        contentDescription = strings.pageListTitle,
                                        tint = if (showThumbStrip) ComicAmber else Color.White.copy(alpha = 0.85f),
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // In-Reader Quick Settings Bottom Sheet
    if (showSettingsSheet) {
        ReaderSettingsBottomSheet(
            readingMode = readingMode,
            settings = settings,
            hasOverlayDialogue = source.hasOverlayDialogue,
            onDismiss = { showSettingsSheet = false },
            onSelectMode = {
                readingMode = it
                onModeChanged(it)
            },
            onSelectFit = onPageFitChanged,
            onSelectFilter = onColorFilterChanged,
            onSelectBg = onBackgroundChanged,
            onSelectDialogue = onDialogueModeChanged,
            onChangeBrightness = onBrightnessChanged,
            onChangeNightWarmth = onNightWarmthChanged,
            onToggleVolumeKeys = onToggleVolumeKeys
        )
    }

    // Bookmark Note Dialog
    if (showNoteDialog) {
        var noteText by remember(currentPage) {
            mutableStateOf(bookmarkNotes[currentPage].orEmpty())
        }
        AlertDialog(
            onDismissRequest = { showNoteDialog = false },
            title = { Text(strings.addBookmarkNote) },
            text = {
                OutlinedTextField(
                    value = noteText,
                    onValueChange = { noteText = it },
                    placeholder = { Text(strings.bookmarkNoteHint) },
                    maxLines = 3,
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        onSaveBookmarkNote(currentPage, noteText)
                        showNoteDialog = false
                        onNoticeMessage(strings.bookmarkAdded)
                    }
                ) {
                    Text(strings.saveAction)
                }
            },
            dismissButton = {
                TextButton(onClick = { showNoteDialog = false }) {
                    Text(strings.cancelAction)
                }
            }
        )
    }
}

@Composable
private fun PagedComicPageSlot(
    source: ComicPageSource,
    pageIndex: Int,
    dialogueLanguage: AppLanguage?,
    pageFitMode: PageFitMode,
    colorFilter: ColorFilter?,
    backgroundColor: Color,
    isRtlNavigation: Boolean,
    guidedPanel: PanelRect?,
    onCenterTap: () -> Unit,
    onNextTap: () -> Unit,
    onPrevTap: () -> Unit
) {
    var bitmap by remember(source, pageIndex) {
        mutableStateOf(source.peekCachedPage(pageIndex, maxWidth = 1440))
    }
    var isLoading by remember(source, pageIndex) { mutableStateOf(bitmap == null) }
    val bubbles = remember(source, pageIndex) { source.getBubbles(pageIndex) }

    LaunchedEffect(source, pageIndex) {
        if (bitmap == null || bitmap?.isRecycled == true) {
            isLoading = true
            bitmap = source.renderPage(pageIndex, maxWidth = 1440, maxHeight = 2200)
            isLoading = false
        }
    }

    ZoomableComicPage(
        bitmap = bitmap,
        isLoading = isLoading,
        bubbles = bubbles,
        dialogueLanguage = dialogueLanguage,
        pageFitMode = pageFitMode,
        colorFilter = colorFilter,
        backgroundColor = backgroundColor,
        isRtlNavigation = isRtlNavigation,
        guidedPanel = guidedPanel,
        resetKey = pageIndex,
        onCenterTap = onCenterTap,
        onNextTap = onNextTap,
        onPrevTap = onPrevTap
    )
}

@Composable
private fun WebtoonStreamView(
    source: ComicPageSource,
    totalPages: Int,
    listState: androidx.compose.foundation.lazy.LazyListState,
    dialogueLanguage: AppLanguage?,
    colorFilter: ColorFilter?,
    backgroundColor: Color,
    onToggleHud: () -> Unit
) {
    var streamScale by remember { mutableFloatStateOf(1f) }
    var streamOffsetX by remember { mutableFloatStateOf(0f) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(backgroundColor)
            .clipToBounds()
            .pointerInput(Unit) {
                detectTapGestures(
                    onDoubleTap = {
                        if (streamScale > 1.1f) {
                            streamScale = 1f
                            streamOffsetX = 0f
                        } else {
                            streamScale = 1.9f
                        }
                    },
                    onTap = { onToggleHud() }
                )
            }
            .pointerInput(Unit) {
                awaitEachGesture {
                    awaitFirstDown(requireUnconsumed = false)
                    do {
                        val event = awaitPointerEvent()
                        val pressedCount = event.changes.count { it.pressed }
                        if (pressedCount >= 2) {
                            val zoom = event.calculateZoom()
                            val pan = event.calculatePan()
                            val next = (streamScale * zoom).coerceIn(1f, 3f)
                            val maxX = size.width * (next - 1f) * 0.5f
                            streamScale = next
                            streamOffsetX = if (next <= 1.02f) 0f
                            else (streamOffsetX + pan.x).coerceIn(-maxX, maxX)
                            event.changes.forEach { if (it.positionChanged()) it.consume() }
                        } else if (streamScale > 1.05f) {
                            val pan = event.calculatePan()
                            if (kotlin.math.abs(pan.x) > kotlin.math.abs(pan.y)) {
                                val maxX = size.width * (streamScale - 1f) * 0.5f
                                streamOffsetX = (streamOffsetX + pan.x).coerceIn(-maxX, maxX)
                                event.changes.forEach { if (it.positionChanged()) it.consume() }
                            }
                        }
                    } while (event.changes.any { it.pressed })
                }
            }
    ) {
        LazyColumn(
            state = listState,
            verticalArrangement = Arrangement.spacedBy(0.dp),
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    scaleX = streamScale
                    scaleY = streamScale
                    translationX = streamOffsetX
                }
        ) {
            items(totalPages, key = { it }) { pageIndex ->
                var bmp by remember(source, pageIndex) { mutableStateOf<Bitmap?>(null) }
                val bubbles = remember(source, pageIndex) { source.getBubbles(pageIndex) }
                LaunchedEffect(source, pageIndex) {
                    bmp = source.renderPage(pageIndex, maxWidth = 1280, maxHeight = 2200)
                }
                val loaded = bmp
                if (loaded != null && !loaded.isRecycled) {
                    ComicPageArtwork(
                        bitmap = loaded,
                        bubbles = bubbles,
                        dialogueLanguage = dialogueLanguage,
                        colorFilter = colorFilter,
                        modifier = Modifier.fillMaxWidth()
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .aspectRatio(2f / 3f),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(
                            color = ComicAmber,
                            strokeWidth = 2.5.dp,
                            modifier = Modifier.size(30.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ReaderMiniThumb(
    source: ComicPageSource,
    pageIndex: Int,
    isSelected: Boolean,
    isBookmarked: Boolean,
    onClick: () -> Unit
) {
    val strings = LocalAppStrings.current
    var bmp by remember(source, pageIndex) { mutableStateOf<Bitmap?>(null) }
    LaunchedEffect(source, pageIndex) {
        bmp = source.renderPage(pageIndex, maxWidth = 220, maxHeight = 330)
    }
    val shape = RoundedCornerShape(8.dp)

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .width(54.dp)
            .clip(shape)
            .clickable(onClick = onClick)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(2f / 3f)
                .clip(shape)
                .background(Color.White.copy(alpha = 0.08f))
                .border(
                    width = if (isSelected) 2.dp else 0.8.dp,
                    color = if (isSelected) ComicAmber else Color.White.copy(alpha = 0.2f),
                    shape = shape
                )
        ) {
            val loaded = bmp
            if (loaded != null && !loaded.isRecycled) {
                Image(
                    bitmap = loaded.asImageBitmap(),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            }
            if (isBookmarked) {
                Icon(
                    imageVector = Icons.Rounded.Bookmark,
                    contentDescription = null,
                    tint = ComicAmber,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(2.dp)
                        .size(12.dp)
                )
            }
        }
        Text(
            text = strings.number(pageIndex + 1),
            style = MaterialTheme.typography.labelSmall,
            color = if (isSelected) ComicAmber else Color.White.copy(alpha = 0.7f)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun ReaderSettingsBottomSheet(
    readingMode: ReadingMode,
    settings: UserSettings,
    hasOverlayDialogue: Boolean,
    onDismiss: () -> Unit,
    onSelectMode: (ReadingMode) -> Unit,
    onSelectFit: (PageFitMode) -> Unit,
    onSelectFilter: (ReaderColorFilter) -> Unit,
    onSelectBg: (ReaderBackground) -> Unit,
    onSelectDialogue: (DialogueDisplayMode) -> Unit,
    onChangeBrightness: (Float) -> Unit,
    onChangeNightWarmth: (Float) -> Unit,
    onToggleVolumeKeys: (Boolean) -> Unit
) {
    val strings = LocalAppStrings.current

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = strings.readerSettingsTitle,
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onSurface
            )

            // Reading Mode
            SheetLabel(strings.readingModeTitle)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                ReadingMode.entries.forEach { mode ->
                    SheetChip(
                        selected = readingMode == mode,
                        label = strings.modeShortLabel(mode),
                        onClick = { onSelectMode(mode) }
                    )
                }
            }

            // Page Fit
            if (readingMode == ReadingMode.PAGED_RTL || readingMode == ReadingMode.PAGED_LTR) {
                SheetLabel(strings.pageFitTitle)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    PageFitMode.entries.forEach { fit ->
                        SheetChip(
                            selected = settings.pageFitMode == fit,
                            label = strings.fitLabel(fit),
                            onClick = { onSelectFit(fit) }
                        )
                    }
                }
            }

            // Dialogue overlay mode
            if (hasOverlayDialogue) {
                SheetLabel(strings.dialogueTitle)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    DialogueDisplayMode.entries.forEach { dm ->
                        SheetChip(
                            selected = settings.dialogueMode == dm,
                            label = strings.dialogueLabel(dm),
                            onClick = { onSelectDialogue(dm) }
                        )
                    }
                }
            }

            // Color Filter
            SheetLabel(strings.colorFilterTitle)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                ReaderColorFilter.entries.forEach { cf ->
                    SheetChip(
                        selected = settings.colorFilter == cf,
                        label = strings.filterColorLabel(cf),
                        onClick = { onSelectFilter(cf) }
                    )
                }
            }

            // Background
            SheetLabel(strings.backgroundTitle)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ReaderBackground.entries.forEach { bg ->
                    SheetChip(
                        selected = settings.readerBackground == bg,
                        label = strings.bgLabel(bg),
                        onClick = { onSelectBg(bg) }
                    )
                }
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)

            // Brightness
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                SheetLabel(strings.brightnessTitle)
                SheetChip(
                    selected = settings.brightnessOverride < 0f,
                    label = strings.brightnessAuto,
                    onClick = {
                        onChangeBrightness(if (settings.brightnessOverride < 0f) 0.75f else -1f)
                    }
                )
            }
            Slider(
                value = if (settings.brightnessOverride < 0f) 0.75f else settings.brightnessOverride,
                onValueChange = { onChangeBrightness(it) },
                valueRange = 0.08f..1f
            )

            // Warm Eye-Comfort Tint
            SheetLabel(strings.nightLightTitle)
            Slider(
                value = settings.nightWarmth,
                onValueChange = { onChangeNightWarmth(it) },
                valueRange = 0f..0.4f
            )

            // Volume Keys Switch
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = strings.settingsVolumeKeysLabel,
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Switch(
                    checked = settings.volumeKeysNavigation,
                    onCheckedChange = onToggleVolumeKeys
                )
            }

            Spacer(Modifier.height(20.dp))
        }
    }
}

@Composable
private fun SheetLabel(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.primary
    )
}

@Composable
private fun SheetChip(
    selected: Boolean,
    label: String,
    onClick: () -> Unit
) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(label, style = MaterialTheme.typography.labelMedium) },
        shape = RoundedCornerShape(10.dp),
        colors = FilterChipDefaults.filterChipColors(
            selectedContainerColor = MaterialTheme.colorScheme.primary,
            selectedLabelColor = MaterialTheme.colorScheme.onPrimary,
            containerColor = MaterialTheme.colorScheme.surfaceContainer
        )
    )
}
