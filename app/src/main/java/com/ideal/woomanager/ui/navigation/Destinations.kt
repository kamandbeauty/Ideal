package com.ideal.woomanager.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Calculate
import androidx.compose.ui.graphics.vector.ImageVector

sealed class Dest(val route: String) {
    data object Dashboard : Dest("dashboard")
    data object Orders : Dest("orders")
    data object Accounting : Dest("accounting")
    data object Products : Dest("products")
    data object Settings : Dest("settings")

    data object OrderDetail : Dest("order/{orderId}") {
        fun create(orderId: Long) = "order/$orderId"
    }
}

data class BottomItem(
    val dest: Dest,
    val label: String,
    val icon: ImageVector
)

val bottomItems = listOf(
    BottomItem(Dest.Dashboard, "داشبورد", Icons.Filled.Dashboard),
    BottomItem(Dest.Orders, "سفارشات", Icons.Filled.ReceiptLong),
    BottomItem(Dest.Accounting, "حسابداری", Icons.Filled.Calculate),
    BottomItem(Dest.Products, "محصولات", Icons.Filled.Inventory2),
    BottomItem(Dest.Settings, "تنظیمات", Icons.Filled.Settings)
)
