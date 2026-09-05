package com.ideal.woomanager.ui.screens.orders

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.ideal.woomanager.data.model.Order
import com.ideal.woomanager.ui.components.ErrorState
import com.ideal.woomanager.ui.components.LoadingState
import com.ideal.woomanager.ui.components.StatusBadge
import com.ideal.woomanager.util.Format
import com.ideal.woomanager.util.OrderStatus
import com.ideal.woomanager.util.repoViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OrderDetailScreen(
    orderId: Long,
    currency: String,
    onBack: () -> Unit
) {
    val vm = repoViewModel { OrderDetailViewModel(it, orderId) }
    val state by vm.state.collectAsState()
    val snackbar = remember { SnackbarHostState() }

    LaunchedEffect(state.message) {
        state.message?.let {
            snackbar.showSnackbar(it)
            vm.clearMessage()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(state.order?.let { "سفارش #${it.number}" } ?: "جزئیات سفارش") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "بازگشت")
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbar) }
    ) { padding ->
        Box(Modifier.padding(padding).fillMaxSize()) {
            when {
                state.loading -> LoadingState()
                state.error != null -> ErrorState(state.error!!, onRetry = vm::load)
                state.order != null -> OrderContent(
                    order = state.order!!,
                    currency = currency,
                    updating = state.updating,
                    onChangeStatus = vm::changeStatus
                )
            }
        }
    }
}

@Composable
private fun OrderContent(
    order: Order,
    currency: String,
    updating: Boolean,
    onChangeStatus: (String) -> Unit
) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Status + change
        Card {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("وضعیت سفارش", fontWeight = FontWeight.Bold)
                    StatusBadge(OrderStatus.label(order.status), OrderStatus.color(order.status))
                }
                StatusChanger(updating = updating, onChangeStatus = onChangeStatus)
            }
        }

        // Customer
        Card {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("اطلاعات مشتری", fontWeight = FontWeight.Bold)
                InfoRow("نام", order.customerName)
                if (order.billing.phone.isNotBlank()) InfoRow("تلفن", order.billing.phone)
                if (order.billing.email.isNotBlank()) InfoRow("ایمیل", order.billing.email)
                if (order.billing.city.isNotBlank()) InfoRow("شهر", order.billing.city)
                if (order.billing.address1.isNotBlank()) InfoRow("آدرس", order.billing.address1)
                InfoRow("تاریخ ثبت", Format.dateTimeFromIso(order.dateCreated))
                if (order.paymentMethodTitle.isNotBlank()) InfoRow("روش پرداخت", order.paymentMethodTitle)
            }
        }

        // Items
        Card {
            Column(Modifier.padding(16.dp)) {
                Text("اقلام سفارش", fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                order.lineItems.forEach { item ->
                    Row(
                        Modifier.fillMaxWidth().padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(item.name, style = MaterialTheme.typography.bodyMedium)
                            Text("تعداد: ${item.quantity}", style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Text(Format.money(item.total, currency), fontWeight = FontWeight.SemiBold)
                    }
                    Divider()
                }
            }
        }

        // Totals
        Card {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("جمع مالی", fontWeight = FontWeight.Bold)
                InfoRow("حمل و نقل", Format.money(order.shippingAmount, currency))
                InfoRow("مالیات", Format.money(order.taxAmount, currency))
                if ((order.discountTotal.toDoubleOrNull() ?: 0.0) > 0)
                    InfoRow("تخفیف", Format.money(order.discountTotal, currency))
                Divider()
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("مبلغ کل", fontWeight = FontWeight.Bold)
                    Text(
                        Format.money(order.totalAmount, currency),
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
        }

        if (order.customerNote.isNotBlank()) {
            Card {
                Column(Modifier.padding(16.dp)) {
                    Text("یادداشت مشتری", fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(4.dp))
                    Text(order.customerNote, style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
        Spacer(Modifier.height(16.dp))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StatusChanger(updating: Boolean, onChangeStatus: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        Button(onClick = { expanded = true }, enabled = !updating, modifier = Modifier.fillMaxWidth()) {
            if (updating) CircularProgressIndicator(Modifier.height(18.dp), strokeWidth = 2.dp)
            else Text("تغییر وضعیت")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            OrderStatus.actionable.forEach { st ->
                DropdownMenuItem(
                    text = { Text(OrderStatus.label(st)) },
                    onClick = {
                        expanded = false
                        onChangeStatus(st)
                    }
                )
            }
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodyMedium)
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
    }
}
