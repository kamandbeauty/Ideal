package com.ideal.woomanager.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Product(
    val id: Long = 0,
    val name: String = "",
    val sku: String = "",
    val price: String = "0",
    @SerialName("regular_price") val regularPrice: String = "0",
    @SerialName("sale_price") val salePrice: String = "",
    @SerialName("stock_quantity") val stockQuantity: Int? = null,
    @SerialName("stock_status") val stockStatus: String = "",
    @SerialName("total_sales") val totalSales: Int = 0,
    val status: String = "",
    val images: List<ProductImage> = emptyList()
) {
    val imageUrl: String? get() = images.firstOrNull()?.src
    val priceValue: Double get() = price.toDoubleOrNull() ?: 0.0
}

@Serializable
data class ProductImage(
    val id: Long = 0,
    val src: String = ""
)
