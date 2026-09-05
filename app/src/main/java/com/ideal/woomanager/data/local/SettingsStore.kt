package com.ideal.woomanager.data.local

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

val Context.dataStore by preferencesDataStore(name = "settings")

data class StoreCredentials(
    val baseUrl: String = "",
    val consumerKey: String = "",
    val consumerSecret: String = "",
    val currencySymbol: String = "تومان"
) {
    val isConfigured: Boolean
        get() = baseUrl.isNotBlank() && consumerKey.isNotBlank() && consumerSecret.isNotBlank()
}

class SettingsStore(private val context: Context) {

    private object Keys {
        val BASE_URL = stringPreferencesKey("base_url")
        val CK = stringPreferencesKey("consumer_key")
        val CS = stringPreferencesKey("consumer_secret")
        val CURRENCY = stringPreferencesKey("currency_symbol")
    }

    val credentials: Flow<StoreCredentials> = context.dataStore.data.map { prefs ->
        StoreCredentials(
            baseUrl = prefs[Keys.BASE_URL] ?: "",
            consumerKey = prefs[Keys.CK] ?: "",
            consumerSecret = prefs[Keys.CS] ?: "",
            currencySymbol = prefs[Keys.CURRENCY] ?: "تومان"
        )
    }

    suspend fun save(creds: StoreCredentials) {
        context.dataStore.edit { prefs ->
            prefs[Keys.BASE_URL] = normalizeUrl(creds.baseUrl)
            prefs[Keys.CK] = creds.consumerKey.trim()
            prefs[Keys.CS] = creds.consumerSecret.trim()
            prefs[Keys.CURRENCY] = creds.currencySymbol.trim().ifBlank { "تومان" }
        }
    }

    suspend fun clear() {
        context.dataStore.edit { it.clear() }
    }

    private fun normalizeUrl(url: String): String {
        var u = url.trim()
        if (u.isEmpty()) return u
        if (!u.startsWith("http://") && !u.startsWith("https://")) u = "https://$u"
        return u.trimEnd('/')
    }
}
