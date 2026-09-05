package com.ideal.woomanager.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Order(
    val id: Long = 0,
    val number: String = "",
    val status: String = "",
    val currency: String = "",
    @SerialName("date_created") val dateCreated: String? = null,
    @SerialName("date_paid") val datePaid: String? = null,
    val total: String = "0",
    @SerialName("total_tax") val totalTax: String = "0",
    @SerialName("shipping_total") val shippingTotal: String = "0",
    @SerialName("discount_total") val discountTotal: String = "0",
    @SerialName("payment_method_title") val paymentMethodTitle: String = "",
    val billing: Billing = Billing(),
    @SerialName("line_items") val lineItems: List<LineItem> = emptyList(),
    @SerialName("customer_note") val customerNote: String = ""
) {
    val customerName: String
        get() = listOf(billing.firstName, billing.lastName)
            .filter { it.isNotBlank() }
            .joinToString(" ")
            .ifBlank { "مشتری مهمان" }

    val totalAmount: Double get() = total.toDoubleOrNull() ?: 0.0
    val taxAmount: Double get() = totalTax.toDoubleOrNull() ?: 0.0
    val shippingAmount: Double get() = shippingTotal.toDoubleOrNull() ?: 0.0
}

@Serializable
data class Billing(
    @SerialName("first_name") val firstName: String = "",
    @SerialName("last_name") val lastName: String = "",
    val company: String = "",
    val city: String = "",
    val phone: String = "",
    val email: String = "",
    @SerialName("address_1") val address1: String = "",
    val state: String = ""
)

@Serializable
data class LineItem(
    val id: Long = 0,
    val name: String = "",
    @SerialName("product_id") val productId: Long = 0,
    val quantity: Int = 0,
    val total: String = "0",
    @SerialName("total_tax") val totalTax: String = "0",
    val sku: String = "",
    val price: Double = 0.0
)
