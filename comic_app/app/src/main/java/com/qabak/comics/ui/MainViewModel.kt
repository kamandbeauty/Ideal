package com.qabak.comics.ui

import android.app.Application
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import androidx.core.content.FileProvider
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.qabak.comics.QabakApplication
import com.qabak.comics.data.parser.ComicPageSource
import com.qabak.comics.data.parser.EmptyComicArchiveException
import com.qabak.comics.data.parser.UnsupportedRar5Exception
import com.qabak.comics.data.repository.ComicRepository
import com.qabak.comics.model.AppLanguage
import com.qabak.comics.model.AppThemeMode
import com.qabak.comics.model.BookmarkItem
import com.qabak.comics.model.ComicBook
import com.qabak.comics.model.DialogueDisplayMode
import com.qabak.comics.model.PageFitMode
import com.qabak.comics.model.ReaderBackground
import com.qabak.comics.model.ReaderColorFilter
import com.qabak.comics.model.ReadingMode
import com.qabak.comics.model.ReadingStats
import com.qabak.comics.model.UserSettings
import com.qabak.comics.ui.i18n.stringsFor
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

sealed interface UiEvent {
    data class ShowSnackbar(val message: String) : UiEvent
    data class OpenComicReader(val comicId: String, val page: Int) : UiEvent
}

class MainViewModel(application: Application) : AndroidViewModel(application) {

    val repository: ComicRepository = (application as QabakApplication).comicRepository

    val settings: StateFlow<UserSettings> = repository.preferences.settingsFlow
        .stateIn(viewModelScope, SharingStarted.Eagerly, UserSettings())

    val comics: StateFlow<List<ComicBook>> = repository.comicsFlow
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val allBookmarks: StateFlow<List<BookmarkItem>> = repository.allBookmarksFlow
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val readingStats: StateFlow<ReadingStats> = repository.readingStatsFlow
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ReadingStats())

    private val _isImporting = MutableStateFlow(false)
    val isImporting: StateFlow<Boolean> = _isImporting.asStateFlow()

    private val _storageBytes = MutableStateFlow(0L)
    val storageBytes: StateFlow<Long> = _storageBytes.asStateFlow()

    private val _isInReader = MutableStateFlow(false)
    val isInReader: StateFlow<Boolean> = _isInReader.asStateFlow()

    private val _events = MutableSharedFlow<UiEvent>(extraBufferCapacity = 8)
    val events = _events.asSharedFlow()

    private val _volumeStepEvents = MutableSharedFlow<Int>(extraBufferCapacity = 8)
    val volumeStepEvents = _volumeStepEvents.asSharedFlow()

    init {
        viewModelScope.launch {
            repository.ensureBundledComicsSeeded()
            refreshStorageUsage()
        }
    }

    fun setReaderActive(active: Boolean) {
        _isInReader.value = active
    }

    fun dispatchVolumeStep(delta: Int): Boolean {
        if (!_isInReader.value || !settings.value.volumeKeysNavigation) return false
        _volumeStepEvents.tryEmit(delta)
        return true
    }

    fun observeComic(comicId: String): Flow<ComicBook?> = repository.observeComic(comicId)
    fun observeComicBookmarks(comicId: String): Flow<List<BookmarkItem>> =
        repository.observeBookmarksForComic(comicId)

    fun openPageSource(comic: ComicBook): Result<ComicPageSource> =
        runCatching { repository.openSource(comic) }

    suspend fun loadCover(coverPath: String): Bitmap? = repository.loadCoverBitmap(coverPath)
    suspend fun loadBookmarkThumb(item: BookmarkItem): Bitmap? = repository.loadBookmarkThumbnail(item)

    fun refreshStorageUsage() {
        viewModelScope.launch {
            _storageBytes.value = repository.calculateStorageBytes()
        }
    }

    fun importComicFile(uri: Uri, openImmediately: Boolean = false) {
        viewModelScope.launch {
            _isImporting.value = true
            val strings = stringsFor(settings.value.language)
            val result = repository.importComicFile(uri, settings.value.defaultReadingMode)
            _isImporting.value = false
            refreshStorageUsage()
            result.onSuccess { comic ->
                _events.emit(UiEvent.ShowSnackbar("${comic.localizedTitle(strings.language)} — ${strings.importSuccess}"))
                if (openImmediately) {
                    _events.emit(UiEvent.OpenComicReader(comic.id, 0))
                }
            }.onFailure { err ->
                val msg = when (err) {
                    is UnsupportedRar5Exception -> strings.importErrorRar5
                    is EmptyComicArchiveException -> strings.importErrorEmpty
                    else -> strings.importErrorGeneric
                }
                _events.emit(UiEvent.ShowSnackbar(msg))
            }
        }
    }

    fun importImageCollection(uris: List<Uri>, customTitle: String) {
        if (uris.isEmpty()) return
        viewModelScope.launch {
            _isImporting.value = true
            val strings = stringsFor(settings.value.language)
            val result = repository.importImageCollection(uris, customTitle, settings.value.defaultReadingMode)
            _isImporting.value = false
            refreshStorageUsage()
            result.onSuccess { comic ->
                _events.emit(UiEvent.ShowSnackbar("${comic.localizedTitle(strings.language)} — ${strings.importSuccess}"))
            }.onFailure { err ->
                val msg = if (err is EmptyComicArchiveException) strings.importErrorEmpty else strings.importErrorGeneric
                _events.emit(UiEvent.ShowSnackbar(msg))
            }
        }
    }

    fun importFolder(treeUri: Uri) {
        viewModelScope.launch {
            _isImporting.value = true
            val strings = stringsFor(settings.value.language)
            val result = repository.importImageFolder(treeUri, settings.value.defaultReadingMode)
            _isImporting.value = false
            refreshStorageUsage()
            result.onSuccess { comic ->
                _events.emit(UiEvent.ShowSnackbar("${comic.localizedTitle(strings.language)} — ${strings.importSuccess}"))
            }.onFailure { err ->
                val msg = if (err is EmptyComicArchiveException) strings.importErrorEmpty else strings.importErrorGeneric
                _events.emit(UiEvent.ShowSnackbar(msg))
            }
        }
    }

    fun shareComicAsCbz(context: Context, comic: ComicBook) {
        viewModelScope.launch {
            val strings = stringsFor(settings.value.language)
            _events.emit(UiEvent.ShowSnackbar(strings.exportingComic))
            repository.exportComicAsCbz(comic).onSuccess { cbzFile ->
                runCatching {
                    val uri = FileProvider.getUriForFile(
                        context,
                        "${context.packageName}.fileprovider",
                        cbzFile
                    )
                    val sendIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/vnd.comicbook+zip"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_SUBJECT, comic.localizedTitle(strings.language))
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    context.startActivity(
                        Intent.createChooser(sendIntent, comic.localizedTitle(strings.language))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                }
            }
        }
    }

    fun updateReadingProgress(comicId: String, pageIndex: Int) {
        viewModelScope.launch { repository.updateReadingProgress(comicId, pageIndex) }
    }

    fun toggleFavorite(comicId: String) {
        viewModelScope.launch { repository.toggleFavorite(comicId) }
    }

    fun toggleCompleted(comicId: String) {
        viewModelScope.launch { repository.toggleCompleted(comicId) }
    }

    fun setComicPreferredMode(comicId: String, mode: ReadingMode) {
        viewModelScope.launch { repository.setPreferredMode(comicId, mode) }
    }

    fun deleteComic(comic: ComicBook) {
        viewModelScope.launch {
            repository.deleteComic(comic)
            refreshStorageUsage()
        }
    }

    fun toggleBookmark(comicId: String, pageIndex: Int) {
        viewModelScope.launch { repository.toggleBookmark(comicId, pageIndex) }
    }

    fun saveBookmarkNote(comicId: String, pageIndex: Int, note: String) {
        viewModelScope.launch { repository.saveBookmarkWithNote(comicId, pageIndex, note) }
    }

    fun deleteBookmark(id: Long) {
        viewModelScope.launch { repository.deleteBookmark(id) }
    }

    // Settings updates
    fun toggleLanguage() {
        viewModelScope.launch { repository.preferences.toggleLanguage() }
    }

    fun setLanguage(lang: AppLanguage) {
        viewModelScope.launch { repository.preferences.setLanguage(lang) }
    }

    fun setThemeMode(mode: AppThemeMode) {
        viewModelScope.launch { repository.preferences.setThemeMode(mode) }
    }

    fun setDefaultReadingMode(mode: ReadingMode) {
        viewModelScope.launch { repository.preferences.setDefaultReadingMode(mode) }
    }

    fun setPageFitMode(mode: PageFitMode) {
        viewModelScope.launch { repository.preferences.setPageFitMode(mode) }
    }

    fun setColorFilter(filter: ReaderColorFilter) {
        viewModelScope.launch { repository.preferences.setColorFilter(filter) }
    }

    fun setReaderBackground(bg: ReaderBackground) {
        viewModelScope.launch { repository.preferences.setReaderBackground(bg) }
    }

    fun setDialogueMode(mode: DialogueDisplayMode) {
        viewModelScope.launch { repository.preferences.setDialogueMode(mode) }
    }

    fun setBrightnessOverride(value: Float) {
        viewModelScope.launch { repository.preferences.setBrightnessOverride(value) }
    }

    fun setNightWarmth(value: Float) {
        viewModelScope.launch { repository.preferences.setNightWarmth(value) }
    }

    fun setVolumeKeys(enabled: Boolean) {
        viewModelScope.launch { repository.preferences.setVolumeKeysNavigation(enabled) }
    }

    fun setKeepScreenOn(enabled: Boolean) {
        viewModelScope.launch { repository.preferences.setKeepScreenOn(enabled) }
    }

    fun setShowPageOverlay(enabled: Boolean) {
        viewModelScope.launch { repository.preferences.setShowPageNumberOverlay(enabled) }
    }

    fun toggleGridColumns() {
        viewModelScope.launch {
            val next = if (settings.value.gridColumns == 1) 2 else 1
            repository.preferences.setGridColumns(next)
        }
    }

    fun clearCache() {
        viewModelScope.launch {
            repository.clearTemporaryCache()
            refreshStorageUsage()
            _events.emit(UiEvent.ShowSnackbar(stringsFor(settings.value.language).settingsCacheClearedToast))
        }
    }

    fun restoreSampleComics() {
        viewModelScope.launch {
            val added = repository.restoreBundledComics()
            val s = stringsFor(settings.value.language)
            val msg = if (added > 0) s.settingsSamplesRestoredToast else s.settingsSamplesAlreadyPresent
            _events.emit(UiEvent.ShowSnackbar(msg))
        }
    }

    fun postNotice(message: String) {
        viewModelScope.launch { _events.emit(UiEvent.ShowSnackbar(message)) }
    }
}
