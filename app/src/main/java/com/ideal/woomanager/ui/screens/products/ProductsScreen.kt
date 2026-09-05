package com.ideal.woomanager.ui.screens.products

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.ideal.woomanager.data.model.Product
import com.ideal.woomanager.ui.components.EmptyState
import com.ideal.woomanager.ui.components.ErrorState
import com.ideal.woomanager.ui.components.LoadingState
import com.ideal.woomanager.ui.components.StatusBadge
import com.ideal.woomanager.ui.theme.Negative
import com.ideal.woomanager.ui.theme.Positive
import com.ideal.woomanager.ui.theme.Warning
import com.ideal.woomanager.util.Format
import com.ideal.woomanager.util.repoViewModel

@Composable
fun ProductsScreen(currency: String) {
    val vm = repoViewModel { ProductsViewModel(it) }
    val state by vm.state.collectAsState()
    val listState = rememberLazyListState()

    val shouldLoadMore by remember {
        derivedStateOf {
            val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            last >= state.products.size - 3 && state.products.isNotEmpty()
        }
    }
    LaunchedEffect(shouldLoadMore) { if (shouldLoadMore) vm.loadMore() }

    Column(Modifier.fillMaxWidth()) {
        OutlinedTextField(
            value = state.search,
            onValueChange = vm::onSearchChange,
            placeholder = { Text("جستجوی محصول") },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
        )
        when {
            state.loading -> LoadingState()
            state.error != null -> ErrorState(state.error!!, onRetry = vm::refresh)
            state.products.isEmpty() -> EmptyState("محصولی یافت نشد")
            else -> LazyColumn(state = listState) {
                items(state.products) { product ->
                    ProductRow(product, currency)
                }
                if (state.loadingMore) {
                    item {
                        Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.Center) {
                            CircularProgressIndicator(Modifier.height(24.dp), strokeWidth = 2.dp)
                        }
                    }
                }
                item { Spacer(Modifier.height(16.dp)) }
            }
        }
    }
}

@Composable
private fun ProductRow(product: Product, currency: String) {
    Card(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp)) {
        Row(Modifier.padding(12.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(56.dp).clip(RoundedCornerShape(8.dp)),
                contentAlignment = Alignment.Center
            ) {
                if (product.imageUrl != null) {
                    AsyncImage(
                        model = product.imageUrl,
                        contentDescription = product.name,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.size(56.dp)
                    )
                } else {
                    Icon(Icons.Default.Image, contentDescription = null, tint = MaterialTheme.colorScheme.outline)
                }
            }
            Spacer(Modifier.size(12.dp))
            Column(Modifier.weight(1f)) {
                Text(product.name, fontWeight = FontWeight.SemiBold, maxLines = 2, style = MaterialTheme.typography.bodyMedium)
                if (product.sku.isNotBlank()) {
                    Text("کد: ${product.sku}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Text(Format.money(product.priceValue, currency), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Medium)
            }
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                StockBadge(product)
                Text("فروش: ${product.totalSales}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun StockBadge(product: Product) {
    val (text, color) = when (product.stockStatus) {
        "instock" -> (product.stockQuantity?.let { "موجودی: $it" } ?: "موجود") to Positive
        "outofstock" -> "ناموجود" to Negative
        "onbackorder" -> "پیش‌سفارش" to Warning
        else -> product.stockStatus to MaterialTheme.colorScheme.outline
    }
    StatusBadge(text, color)
}
