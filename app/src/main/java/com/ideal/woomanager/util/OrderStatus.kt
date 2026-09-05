package com.ideal.woomanager.util

import androidx.compose.ui.graphics.Color

object OrderStatus {
    /** WooCommerce core order statuses + Persian labels. */
    val labels = linkedMapOf(
        "pending" to "در انتظار پرداخت",
        "processing" to "در حال پردازش",
        "on-hold" to "در انتظار بررسی",
        "completed" to "تکمیل شده",
        "cancelled" to "لغو شده",
        "refunded" to "مسترد شده",
        "failed" to "ناموفق",
        "trash" to "حذف شده"
    )

    /** Statuses offered as filter chips (plus "any"). */
    val filterable = listOf("any", "pending", "processing", "on-hold", "completed", "cancelled", "refunded")

    /** Statuses a user can transition an order to from the app. */
    val actionable = listOf("processing", "completed", "on-hold", "cancelled", "refunded")

    fun label(status: String): String = labels[status] ?: status

    fun color(status: String): Color = when (status) {
        "completed" -> Color(0xFF2E7D32)
        "processing" -> Color(0xFF0288D1)
        "on-hold" -> Color(0xFFED6C02)
        "pending" -> Color(0xFF9E9E9E)
        "cancelled", "failed", "trash" -> Color(0xFFC62828)
        "refunded" -> Color(0xFF6A1B9A)
        else -> Color(0xFF607D8B)
    }

    fun filterLabel(status: String): String =
        if (status == "any") "همه" else label(status)
}
