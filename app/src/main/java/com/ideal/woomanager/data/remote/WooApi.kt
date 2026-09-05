package com.ideal.woomanager.data.remote

import com.ideal.woomanager.data.model.Order
import com.ideal.woomanager.data.model.Product
import com.ideal.woomanager.data.model.SalesReport
import com.ideal.woomanager.data.model.TopSeller
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.PUT
import retrofit2.http.Path
import retrofit2.http.Query
import retrofit2.http.QueryMap

interface WooApi {

    @GET("wp-json/wc/v3/orders")
    suspend fun getOrders(
        @QueryMap params: Map<String, String> = emptyMap()
    ): Response<List<Order>>

    @GET("wp-json/wc/v3/orders/{id}")
    suspend fun getOrder(@Path("id") id: Long): Response<Order>

    @PUT("wp-json/wc/v3/orders/{id}")
    suspend fun updateOrderStatus(
        @Path("id") id: Long,
        @Body body: Map<String, String>
    ): Response<Order>

    @GET("wp-json/wc/v3/products")
    suspend fun getProducts(
        @QueryMap params: Map<String, String> = emptyMap()
    ): Response<List<Product>>

    @GET("wp-json/wc/v3/reports/sales")
    suspend fun getSalesReport(
        @QueryMap params: Map<String, String> = emptyMap()
    ): Response<List<SalesReport>>

    @GET("wp-json/wc/v3/reports/top_sellers")
    suspend fun getTopSellers(
        @QueryMap params: Map<String, String> = emptyMap()
    ): Response<List<TopSeller>>

    // Simple connectivity/auth check
    @GET("wp-json/wc/v3/system_status")
    suspend fun systemStatus(): Response<Unit>
}
