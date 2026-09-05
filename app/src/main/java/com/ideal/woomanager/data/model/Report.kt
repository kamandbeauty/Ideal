package com.ideal.woomanager.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** WooCommerce /reports/sales response item */
@Serializable
data class SalesReport(
    @SerialName("total_sales") val totalSales: String = "0",
    @SerialName("net_sales") val netSales: String = "0",
    @SerialName("average_sales") val averageSales: String = "0",
    @SerialName("total_orders") val totalOrders: Int = 0,
    @SerialName("total_items") val totalItems: Int = 0,
    @SerialName("total_tax") val totalTax: String = "0",
    @SerialName("total_shipping") val totalShipping: String = "0",
    @SerialName("total_refunds") val totalRefunds: Double = 0.0,
    @SerialName("total_discount") val totalDiscount: String = "0",
    @SerialName("totals") val totals: Map<String, DailyTotal> = emptyMap()
)

@Serializable
data class DailyTotal(
    val sales: String = "0",
    val orders: Int = 0,
    val items: Int = 0,
    val tax: String = "0",
    val shipping: String = "0",
    val discount: String = "0",
    val customers: Int = 0
)

/** WooCommerce /reports/top_sellers item */
@Serializable
data class TopSeller(
    val title: String = "",
    @SerialName("product_id") val productId: Long = 0,
    val quantity: Int = 0
)
