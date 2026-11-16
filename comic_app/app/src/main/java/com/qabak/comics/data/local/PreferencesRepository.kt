package com.qabak.comics.data.local

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.qabak.comics.model.AppLanguage
import com.qabak.comics.model.AppThemeMode
import com.qabak.comics.model.DialogueDisplayMode
import com.qabak.comics.model.PageFitMode
import com.qabak.comics.model.ReaderBackground
import com.qabak.comics.model.ReaderColorFilter
import com.qabak.comics.model.ReadingMode
import com.qabak.comics.model.UserSettings
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import java.io.IOException

private val Context.qabakDataStore: DataStore<Preferences> by preferencesDataStore(name = "qabak_settings")

class PreferencesRepository(private val dataStore: DataStore<Preferences>) {

    constructor(context: Context) : this(context.applicationContext.qabakDataStore)

    private object Keys {
        val LANGUAGE = stringPreferencesKey("language")
        val THEME_MODE = stringPreferencesKey("theme_mode")
        val DEFAULT_READING_MODE = stringPreferencesKey("default_reading_mode")
        val PAGE_FIT_MODE = stringPreferencesKey("page_fit_mode")
        val COLOR_FILTER = stringPreferencesKey("color_filter")
        val READER_BG = stringPreferencesKey("reader_background")
        val DIALOGUE_MODE = stringPreferencesKey("dialogue_mode")
        val VOLUME_KEYS = booleanPreferencesKey("volume_keys_nav")
        val KEEP_SCREEN_ON = booleanPreferencesKey("keep_screen_on")
        val SHOW_PAGE_OVERLAY = booleanPreferencesKey("show_page_overlay")
        val BRIGHTNESS = floatPreferencesKey("brightness_override")
        val NIGHT_WARMTH = floatPreferencesKey("night_warmth")
        val GRID_COLUMNS = intPreferencesKey("grid_columns")
        val SEEDED_VERSION = intPreferencesKey("seeded_version")
    }

    val settingsFlow: Flow<UserSettings> = dataStore.data
        .catch { e ->
            if (e is IOException) emit(androidx.datastore.preferences.core.emptyPreferences())
            else throw e
        }
        .map { prefs ->
            UserSettings(
                language = prefs[Keys.LANGUAGE]?.let { safeEnum(it, AppLanguage.FA) } ?: AppLanguage.FA,
                themeMode = prefs[Keys.THEME_MODE]?.let { safeEnum(it, AppThemeMode.DARK) } ?: AppThemeMode.DARK,
                defaultReadingMode = prefs[Keys.DEFAULT_READING_MODE]?.let { safeEnum(it, ReadingMode.PAGED_RTL) }
                    ?: ReadingMode.PAGED_RTL,
                pageFitMode = prefs[Keys.PAGE_FIT_MODE]?.let { safeEnum(it, PageFitMode.FIT_PAGE) }
                    ?: PageFitMode.FIT_PAGE,
                colorFilter = prefs[Keys.COLOR_FILTER]?.let { safeEnum(it, ReaderColorFilter.NONE) }
                    ?: ReaderColorFilter.NONE,
                readerBackground = prefs[Keys.READER_BG]?.let { safeEnum(it, ReaderBackground.BLACK) }
                    ?: ReaderBackground.BLACK,
                dialogueMode = prefs[Keys.DIALOGUE_MODE]?.let { safeEnum(it, DialogueDisplayMode.MATCH_APP) }
                    ?: DialogueDisplayMode.MATCH_APP,
                volumeKeysNavigation = prefs[Keys.VOLUME_KEYS] ?: true,
                keepScreenOn = prefs[Keys.KEEP_SCREEN_ON] ?: true,
                showPageNumberOverlay = prefs[Keys.SHOW_PAGE_OVERLAY] ?: true,
                brightnessOverride = prefs[Keys.BRIGHTNESS] ?: -1f,
                nightWarmth = (prefs[Keys.NIGHT_WARMTH] ?: 0f).coerceIn(0f, 0.45f),
                gridColumns = (prefs[Keys.GRID_COLUMNS] ?: 2).coerceIn(1, 3),
                seededVersion = prefs[Keys.SEEDED_VERSION] ?: 0
            )
        }

    suspend fun setLanguage(language: AppLanguage) {
        dataStore.edit { it[Keys.LANGUAGE] = language.name }
    }

    suspend fun toggleLanguage() {
        dataStore.edit { prefs ->
            val current = prefs[Keys.LANGUAGE]?.let { safeEnum(it, AppLanguage.FA) } ?: AppLanguage.FA
            prefs[Keys.LANGUAGE] = if (current == AppLanguage.FA) AppLanguage.EN.name else AppLanguage.FA.name
        }
    }

    suspend fun setThemeMode(mode: AppThemeMode) {
        dataStore.edit { it[Keys.THEME_MODE] = mode.name }
    }

    suspend fun setDefaultReadingMode(mode: ReadingMode) {
        dataStore.edit { it[Keys.DEFAULT_READING_MODE] = mode.name }
    }

    suspend fun setPageFitMode(mode: PageFitMode) {
        dataStore.edit { it[Keys.PAGE_FIT_MODE] = mode.name }
    }

    suspend fun setColorFilter(filter: ReaderColorFilter) {
        dataStore.edit { it[Keys.COLOR_FILTER] = filter.name }
    }

    suspend fun setReaderBackground(bg: ReaderBackground) {
        dataStore.edit { it[Keys.READER_BG] = bg.name }
    }

    suspend fun setDialogueMode(mode: DialogueDisplayMode) {
        dataStore.edit { it[Keys.DIALOGUE_MODE] = mode.name }
    }

    suspend fun setVolumeKeysNavigation(enabled: Boolean) {
        dataStore.edit { it[Keys.VOLUME_KEYS] = enabled }
    }

    suspend fun setKeepScreenOn(enabled: Boolean) {
        dataStore.edit { it[Keys.KEEP_SCREEN_ON] = enabled }
    }

    suspend fun setShowPageNumberOverlay(enabled: Boolean) {
        dataStore.edit { it[Keys.SHOW_PAGE_OVERLAY] = enabled }
    }

    suspend fun setBrightnessOverride(value: Float) {
        dataStore.edit { it[Keys.BRIGHTNESS] = if (value < 0f) -1f else value.coerceIn(0.08f, 1f) }
    }

    suspend fun setNightWarmth(value: Float) {
        dataStore.edit { it[Keys.NIGHT_WARMTH] = value.coerceIn(0f, 0.45f) }
    }

    suspend fun setGridColumns(columns: Int) {
        dataStore.edit { it[Keys.GRID_COLUMNS] = columns.coerceIn(1, 3) }
    }

    suspend fun setSeededVersion(version: Int) {
        dataStore.edit { it[Keys.SEEDED_VERSION] = version }
    }

    private inline fun <reified T : Enum<T>> safeEnum(name: String, fallback: T): T =
        runCatching { enumValueOf<T>(name) }.getOrDefault(fallback)
}
