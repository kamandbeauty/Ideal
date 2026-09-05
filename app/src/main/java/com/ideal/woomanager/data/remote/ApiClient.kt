package com.ideal.woomanager.data.remote

import com.ideal.woomanager.data.local.StoreCredentials
import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import java.util.concurrent.TimeUnit

/**
 * Builds a [WooApi] bound to the current store credentials. Recreated whenever
 * credentials change so the base URL + auth stay in sync.
 */
object ApiClient {

    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        isLenient = true
    }

    @Volatile private var cachedCreds: StoreCredentials? = null
    @Volatile private var cachedApi: WooApi? = null

    fun api(creds: StoreCredentials): WooApi {
        val current = cachedApi
        if (current != null && cachedCreds == creds) return current
        return build(creds).also {
            cachedApi = it
            cachedCreds = creds
        }
    }

    private fun build(creds: StoreCredentials): WooApi {
        val logging = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BASIC
        }

        val client = OkHttpClient.Builder()
            .addInterceptor(AuthInterceptor { creds.consumerKey to creds.consumerSecret })
            .addInterceptor(logging)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()

        val base = creds.baseUrl.trimEnd('/') + "/"

        return Retrofit.Builder()
            .baseUrl(base)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
            .create(WooApi::class.java)
    }
}
