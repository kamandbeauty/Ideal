package com.ideal.woomanager.ui.screens.dashboard

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.item
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.MoneyOff
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.Card
import androidx.compose.material3.Divider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.ideal.woomanager.data.local.StoreCredentials
import com.ideal.woomanager.ui.components.EmptyState
import com.ideal.woomanager.ui.components.ErrorState
import com.ideal.woomanager.ui.components.LoadingState
import com.ideal.woomanager.ui.components.MetricCard
import com.ideal.woomanager.ui.components.RangeSelector
import com.ideal.woomanager.ui.components.SectionHeader
import com.ideal.woomanager.ui.components.StatusBadge
import com.ideal.woomanager.ui.theme.Info
import com.ideal.woomanager.ui.theme.Negative
import com.ideal.woomanager.ui.theme.Positive
import com.ideal.woomanager.ui.theme.Primary
import com.ideal.woomanager.ui.theme.Warning
import com.ideal.woomanager.util.Format
import com.ideal.woomanager.util.OrderStatus
import com.ideal.woomanager.util.repoViewModel

@Composable
fun DashboardScreen(
    currency: String,
    onOpenOrder: (Long) -> Unit,
    onOpenSettings: () -> Unit
) {
    val vm = repoViewModel { DashboardViewModel(it) }
    val state by vm.state.collectAsState()

    when {
        !state.configured -> NotConfigured(onOpenSettings)
        state.loading -> LoadingState()
        state.error != null -> ErrorState(state.error!!, onRetry = vm::load)
        else -> LazyColumn(
            Modifier.fillMaxWidth(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 16.dp)
        ) {
            item {
                RangeSelector(selected = state.range, onSelect = vm::setRange)
            }
            item { Spacer(Modifier.height(4.dp)) }
            item {
                Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        MetricCard(
                            "درآمد کل", Format.money(state.revenue, currency),
                            Icons.Filled.Payments, Primary, Modifier.weight(1f)
                        )
                        MetricCard(
                            "فروش خالص", Format.money(state.netSales, currency),
                            Icons.Filled.TrendingUp, Info, Modifier.weight(1f)
                        )
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        MetricCard(
                            "هزینه‌ها", Format.money(state.expenses, currency),
                            Icons.Filled.MoneyOff, Negative, Modifier.weight(1f)
                        )
                        MetricCard(
                            "سود خالص", Format.money(state.profit, currency),
                            Icons.Filled.AccountBalanceWallet,
                            if (state.profit >= 0) Positive else Negative,
                            Modifier.weight(1f),
                            subtitle = if (state.profit >= 0) "سودده" else "زیان‌ده"
                        )
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        MetricCard(
                            "تعداد سفارش", Format.number(state.report.totalOrders),
                            Icons.Filled.ShoppingCart, Warning, Modifier.weight(1f)
                        )
                        MetricCard(
                            "مالیات", Format.money(state.tax, currency),
                            Icons.Filled.Receipt, Info, Modifier.weight(1f)
                        )
                    }
                    MetricCard(
                        "هزینه حمل و نقل", Format.money(state.shipping, currency),
                        Icons.Filled.LocalShipping, Primary, Modifier.fillMaxWidth()
                    )
                }
            }

            item { Spacer(Modifier.height(8.dp)); SectionHeader("پرفروش‌ترین محصولات") }
            if (state.topSellers.isEmpty()) {
                item { Text("داده‌ای موجود نیست", Modifier.padding(16.dp), color = MaterialTheme.colorScheme.outline) }
            } else {
                item {
                    Card(Modifier.padding(horizontal = 16.dp).fillMaxWidth()) {
                        Column(Modifier.padding(vertical = 4.dp)) {
                            state.topSellers.forEachIndexed { i, s ->
                                Row(
                                    Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(s.title, style = MaterialTheme.typography.bodyMedium)
                                    Text("${s.quantity} عدد", fontWeight = FontWeight.SemiBold)
                                }
                                if (i < state.topSellers.lastIndex) Divider(Modifier.padding(horizontal = 16.dp))
                            }
                        }
                    }
                }
            }

            item { Spacer(Modifier.height(8.dp)); SectionHeader("آخرین سفارشات") }
            if (state.recentOrders.isEmpty()) {
                item { EmptyState("سفارشی وجود ندارد", Modifier.height(140.dp)) }
            } else {
                items(state.recentOrders) { order ->
                    Card(
                        Modifier.padding(horizontal = 16.dp, vertical = 4.dp).fillMaxWidth()
                    ) {
                        Row(
                            Modifier.padding(16.dp).fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text("#${order.number} — ${order.customerName}", fontWeight = FontWeight.SemiBold)
                                Text(
                                    Format.money(order.totalAmount, currency),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            StatusBadge(OrderStatus.label(order.status), OrderStatus.color(order.status))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NotConfigured(onOpenSettings: () -> Unit) {
    androidx.compose.foundation.layout.Box(
        Modifier.fillMaxWidth().padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("هنوز به فروشگاهی متصل نشده‌اید", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(
                "برای مشاهده گزارش‌ها، ابتدا آدرس سایت و کلید API ووکامرس را در بخش تنظیمات وارد کنید.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            androidx.compose.material3.Button(onClick = onOpenSettings) { Text("رفتن به تنظیمات") }
        }
    }
}
