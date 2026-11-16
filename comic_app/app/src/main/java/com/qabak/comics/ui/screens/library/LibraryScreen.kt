package com.qabak.comics.ui.screens.library

import android.graphics.Bitmap
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Sort
import androidx.compose.material.icons.automirrored.rounded.ViewList
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AutoStories
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.qabak.comics.model.ComicBook
import com.qabak.comics.model.ComicSourceType
import com.qabak.comics.model.LibraryFilter
import com.qabak.comics.model.LibrarySort
import com.qabak.comics.ui.components.ComicGridCard
import com.qabak.comics.ui.components.ComicListRowCard
import com.qabak.comics.ui.components.ContinueReadingHeroCard
import com.qabak.comics.ui.i18n.LocalAppStrings

@Composable
fun LibraryScreen(
    comics: List<ComicBook>,
    gridColumnsPref: Int,
    isImporting: Boolean,
    loadCover: suspend (String) -> Bitmap?,
    onToggleLanguage: () -> Unit,
    onToggleGridMode: () -> Unit,
    onOpenImportSheet: () -> Unit,
    onOpenComicDetail: (ComicBook) -> Unit,
    onOpenComicReader: (ComicBook, Int) -> Unit,
    onToggleFavorite: (ComicBook) -> Unit,
    modifier: Modifier = Modifier
) {
    val strings = LocalAppStrings.current
    var searchVisible by rememberSaveable { mutableStateOf(false) }
    var searchQuery by rememberSaveable { mutableStateOf("") }
    var selectedFilter by rememberSaveable { mutableStateOf(LibraryFilter.ALL) }
    var selectedSort by rememberSaveable { mutableStateOf(LibrarySort.RECENT) }
    var sortMenuExpanded by remember { mutableStateOf(false) }

    val screenWidthDp = LocalConfiguration.current.screenWidthDp
    val isListMode = gridColumnsPref == 1
    val effectiveColumns = when {
        isListMode -> 1
        screenWidthDp >= 840 -> 4
        screenWidthDp >= 600 -> 3
        else -> 2
    }

    val heroComic = remember(comics) {
        comics.filter { it.isStarted && !it.isCompleted }.maxByOrNull { it.lastReadAt }
            ?: comics.firstOrNull()
    }

    val filteredComics = remember(comics, searchQuery, selectedFilter, selectedSort, strings.language) {
        val q = searchQuery.trim().lowercase()
        comics
            .asSequence()
            .filter { comic ->
                when (selectedFilter) {
                    LibraryFilter.ALL -> true
                    LibraryFilter.READING -> comic.isStarted && !comic.isCompleted
                    LibraryFilter.COMPLETED -> comic.isCompleted
                    LibraryFilter.FAVORITES -> comic.isFavorite
                    LibraryFilter.IMPORTED -> comic.sourceType != ComicSourceType.BUNDLED
                }
            }
            .filter { comic ->
                if (q.isEmpty()) true
                else {
                    comic.titleFa.lowercase().contains(q) ||
                        comic.titleEn.lowercase().contains(q) ||
                        comic.authorFa.lowercase().contains(q) ||
                        comic.authorEn.lowercase().contains(q) ||
                        comic.genreFa.lowercase().contains(q) ||
                        comic.genreEn.lowercase().contains(q)
                }
            }
            .sortedWith(
                when (selectedSort) {
                    LibrarySort.RECENT -> compareByDescending<ComicBook> { it.lastReadAt }
                        .thenByDescending { it.addedAt }
                    LibrarySort.TITLE -> compareBy { it.localizedTitle(strings.language).lowercase() }
                    LibrarySort.PROGRESS -> compareByDescending<ComicBook> { it.progressFraction }
                        .thenByDescending { it.lastReadAt }
                    LibrarySort.DATE_ADDED -> compareByDescending { it.addedAt }
                }
            )
            .toList()
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
        ) {
            // Editorial Top App Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    // Comic emblem badge
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(MaterialTheme.colorScheme.primary),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.AutoStories,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier.size(22.dp)
                        )
                    }
                    Column {
                        Text(
                            text = strings.appName,
                            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.ExtraBold),
                            color = MaterialTheme.colorScheme.onBackground
                        )
                        Text(
                            text = strings.appTagline,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    IconButton(
                        onClick = {
                            searchVisible = !searchVisible
                            if (!searchVisible) searchQuery = ""
                        }
                    ) {
                        Icon(
                            imageVector = if (searchVisible) Icons.Rounded.Close else Icons.Rounded.Search,
                            contentDescription = strings.searchPlaceholder,
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }

                    IconButton(onClick = onToggleGridMode) {
                        Icon(
                            imageVector = if (isListMode) {
                                Icons.Rounded.GridView
                            } else {
                                Icons.AutoMirrored.Rounded.ViewList
                            },
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }

                    // Instant 1-tap Bilingual Pill Toggle (FA <-> EN)
                    Surface(
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .clickable(onClick = onToggleLanguage),
                        shape = RoundedCornerShape(10.dp),
                        color = MaterialTheme.colorScheme.surfaceContainerHigh,
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline)
                    ) {
                        Text(
                            text = strings.langToggleBadge,
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(horizontal = 11.dp, vertical = 6.dp)
                        )
                    }
                }
            }

            // Collapsible Search Input
            AnimatedVisibility(visible = searchVisible) {
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    placeholder = { Text(strings.searchPlaceholder) },
                    leadingIcon = { Icon(Icons.Rounded.Search, contentDescription = null) },
                    trailingIcon = {
                        if (searchQuery.isNotEmpty()) {
                            IconButton(onClick = { searchQuery = "" }) {
                                Icon(Icons.Rounded.Close, contentDescription = null)
                            }
                        }
                    },
                    singleLine = true,
                    shape = RoundedCornerShape(14.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedContainerColor = MaterialTheme.colorScheme.surfaceContainer,
                        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainer
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 4.dp)
                )
            }

            // Import status banner
            AnimatedVisibility(visible = isImporting) {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                    shape = RoundedCornerShape(12.dp),
                    color = MaterialTheme.colorScheme.primaryContainer
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            strokeWidth = 2.2.dp,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                        Text(
                            text = strings.importingInProgress,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    }
                }
            }

            // Main Scrollable Bookshelf Grid
            LazyVerticalGrid(
                columns = GridCells.Fixed(effectiveColumns),
                contentPadding = PaddingValues(
                    start = 16.dp,
                    end = 16.dp,
                    top = 6.dp,
                    bottom = 96.dp
                ),
                horizontalArrangement = Arrangement.spacedBy(13.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
                modifier = Modifier.fillMaxSize()
            ) {
                // Hero Continue Reading Banner
                if (heroComic != null && selectedFilter == LibraryFilter.ALL && searchQuery.isBlank()) {
                    item(span = { GridItemSpan(maxLineSpan) }, key = "hero_banner") {
                        ContinueReadingHeroCard(
                            comic = heroComic,
                            loadCover = loadCover,
                            onResumeClick = {
                                val target = if (heroComic.isCompleted) 0 else heroComic.currentPage
                                onOpenComicReader(heroComic, target)
                            },
                            onCardClick = { onOpenComicDetail(heroComic) }
                        )
                    }
                }

                // Filter Chips Row
                item(span = { GridItemSpan(maxLineSpan) }, key = "filter_chips") {
                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        items(LibraryFilter.entries) { filter ->
                            val selected = filter == selectedFilter
                            FilterChip(
                                selected = selected,
                                onClick = { selectedFilter = filter },
                                label = {
                                    Text(
                                        text = strings.filterLabel(filter),
                                        style = MaterialTheme.typography.labelMedium
                                    )
                                },
                                shape = RoundedCornerShape(10.dp),
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = MaterialTheme.colorScheme.primary,
                                    selectedLabelColor = MaterialTheme.colorScheme.onPrimary,
                                    containerColor = MaterialTheme.colorScheme.surfaceContainer
                                ),
                                border = FilterChipDefaults.filterChipBorder(
                                    enabled = true,
                                    selected = selected,
                                    borderColor = MaterialTheme.colorScheme.outlineVariant
                                )
                            )
                        }
                    }
                }

                // Shelf Title + Count + Sort Menu
                item(span = { GridItemSpan(maxLineSpan) }, key = "shelf_header") {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Text(
                                text = strings.shelfSectionTitle,
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onBackground
                            )
                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = MaterialTheme.colorScheme.surfaceContainerHigh
                            ) {
                                Text(
                                    text = strings.number(filteredComics.size),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(horizontal = 7.dp, vertical = 2.dp)
                                )
                            }
                        }

                        Box {
                            Surface(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(9.dp))
                                    .clickable { sortMenuExpanded = true },
                                shape = RoundedCornerShape(9.dp),
                                color = MaterialTheme.colorScheme.surfaceContainer
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(5.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.AutoMirrored.Rounded.Sort,
                                        contentDescription = strings.sortLabel,
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Text(
                                        text = strings.sortLabelFor(selectedSort),
                                        style = MaterialTheme.typography.labelMedium,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                }
                            }

                            DropdownMenu(
                                expanded = sortMenuExpanded,
                                onDismissRequest = { sortMenuExpanded = false }
                            ) {
                                LibrarySort.entries.forEach { sort ->
                                    DropdownMenuItem(
                                        text = {
                                            Text(
                                                text = strings.sortLabelFor(sort),
                                                fontWeight = if (sort == selectedSort) {
                                                    FontWeight.Bold
                                                } else {
                                                    FontWeight.Normal
                                                },
                                                color = if (sort == selectedSort) {
                                                    MaterialTheme.colorScheme.primary
                                                } else {
                                                    MaterialTheme.colorScheme.onSurface
                                                }
                                            )
                                        },
                                        onClick = {
                                            selectedSort = sort
                                            sortMenuExpanded = false
                                        }
                                    )
                                }
                            }
                        }
                    }
                }

                // Bookshelf Items or Empty State
                if (filteredComics.isEmpty()) {
                    item(span = { GridItemSpan(maxLineSpan) }, key = "empty_state") {
                        EmptyShelfCard(
                            isLibraryCompletelyEmpty = comics.isEmpty(),
                            modifier = Modifier.padding(vertical = 28.dp)
                        )
                    }
                } else {
                    items(
                        items = filteredComics,
                        key = { it.id }
                    ) { comic ->
                        if (isListMode) {
                            ComicListRowCard(
                                comic = comic,
                                loadCover = loadCover,
                                onClick = { onOpenComicDetail(comic) },
                                onToggleFavorite = { onToggleFavorite(comic) }
                            )
                        } else {
                            ComicGridCard(
                                comic = comic,
                                loadCover = loadCover,
                                onClick = { onOpenComicDetail(comic) },
                                onToggleFavorite = { onToggleFavorite(comic) }
                            )
                        }
                    }
                }
            }
        }

        // Import FAB
        ExtendedFloatingActionButton(
            onClick = onOpenImportSheet,
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = MaterialTheme.colorScheme.onPrimary,
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 16.dp, bottom = 16.dp)
        ) {
            Icon(Icons.Rounded.Add, contentDescription = null)
            Spacer(Modifier.width(6.dp))
            Text(
                text = strings.importComic,
                style = MaterialTheme.typography.labelLarge
            )
        }
    }
}

@Composable
private fun EmptyShelfCard(
    isLibraryCompletelyEmpty: Boolean,
    modifier: Modifier = Modifier
) {
    val strings = LocalAppStrings.current
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceContainer,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = Icons.Rounded.AutoStories,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.8f),
                modifier = Modifier.size(44.dp)
            )
            Text(
                text = if (isLibraryCompletelyEmpty) strings.emptyLibraryTitle else strings.emptyFilterTitle,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center
            )
            Text(
                text = if (isLibraryCompletelyEmpty) strings.emptyLibrarySubtitle else strings.emptyFilterSubtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
        }
    }
}
