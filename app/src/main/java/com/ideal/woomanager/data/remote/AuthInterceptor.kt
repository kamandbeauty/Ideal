package com.ideal.woomanager.data.remote

import okhttp3.Credentials
import okhttp3.Interceptor
import okhttp3.Response

/**
 * Adds WooCommerce REST auth. Over HTTPS the recommended method is HTTP Basic Auth
 * with consumer key/secret. Also appends them as query params as a fallback for
 * servers that strip the Authorization header.
 */
class AuthInterceptor(
    private val keyProvider: () -> Pair<String, String>
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val (ck, cs) = keyProvider()
        val original = chain.request()

        val urlBuilder = original.url.newBuilder()
        if (original.url.queryParameter("consumer_key") == null && ck.isNotBlank()) {
            urlBuilder.addQueryParameter("consumer_key", ck)
            urlBuilder.addQueryParameter("consumer_secret", cs)
        }

        val builder = original.newBuilder()
            .url(urlBuilder.build())
            .header("Accept", "application/json")

        if (ck.isNotBlank() && cs.isNotBlank()) {
            builder.header("Authorization", Credentials.basic(ck, cs))
        }

        return chain.proceed(builder.build())
    }
}
