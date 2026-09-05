package com.ideal.woomanager.ui.screens.orders

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.ideal.woomanager.ui.components.EmptyState
import com.ideal.woomanager.ui.components.ErrorState
import com.ideal.woomanager.ui.components.LoadingState
import com.ideal.woomanager.ui.components.StatusBadge
import com.ideal.woomanager.util.Format
import com.ideal.woomanager.util.OrderStatus
import com.ideal.woomanager.util.repoViewModel

@Composable
fun OrdersScreen(
    currency: String,
    onOpenOrder: (Long) -> Unit
) {
    val vm = repoViewModel { OrdersViewModel(it) }
    val state by vm.state.collectAsState()
    val listState = rememberLazyListState()

    val shouldLoadMore by remember {
        derivedStateOf {
            val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            last >= state.orders.size - 3 && state.orders.isNotEmpty()
        }
    }
    LaunchedEffect(shouldLoadMore) {
        if (shouldLoadMore) vm.loadMore()
    }

    Column(Modifier.fillMaxWidth()) {
        OutlinedTextField(
            value = state.search,
            onValueChange = vm::onSearchChange,
            placeholder = { Text("جستجو (نام، شماره سفارش...)") },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
        )

        Row(
            Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OrderStatus.filterable.forEach { st ->
                FilterChip(
                    selected = state.status == st,
                    onClick = { vm.setStatus(st) },
                    label = { Text(OrderStatus.filterLabel(st)) }
                )
            }
        }

        Spacer(Modifier.height(8.dp))

        when {
            state.loading -> LoadingState()
            state.error != null -> ErrorState(state.error!!, onRetry = vm::refresh)
            state.orders.isEmpty() -> EmptyState("سفارشی یافت نشد")
            else -> LazyColumn(state = listState, modifier = Modifier.fillMaxWidth()) {
                items(state.orders) { order ->
                    Card(
                        Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 4.dp),
                        onClick = { onOpenOrder(order.id) }
                    ) {
                        Column(Modifier.padding(16.dp)) {
                            Row(
                                Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text("#${order.number}", fontWeight = FontWeight.Bold)
                                StatusBadge(OrderStatus.label(order.status), OrderStatus.color(order.status))
                            }
                            Spacer(Modifier.height(6.dp))
                            Text(order.customerName, style = MaterialTheme.typography.bodyMedium)
                            Spacer(Modifier.height(4.dp))
                            Row(
                                Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    Format.dateTimeFromIso(order.dateCreated),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Text(
                                    Format.money(order.totalAmount, currency),
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            }
                        }
                    }
                }
                if (state.loadingMore) {
                    item {
                        Row(
                            Modifier.fillMaxWidth().padding(16.dp),
                            horizontalArrangement = Arrangement.Center
                        ) { CircularProgressIndicator(Modifier.height(24.dp), strokeWidth = 2.dp) }
                    }
                }
                item { Spacer(Modifier.height(16.dp)) }
            }
        }
    }
}
