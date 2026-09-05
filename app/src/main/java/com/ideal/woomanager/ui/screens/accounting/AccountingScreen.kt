package com.ideal.woomanager.ui.screens.accounting

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Card
import androidx.compose.material3.Divider
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.ideal.woomanager.ui.components.EmptyState
import com.ideal.woomanager.ui.components.RangeSelector
import com.ideal.woomanager.ui.components.SectionHeader
import com.ideal.woomanager.ui.theme.Info
import com.ideal.woomanager.ui.theme.Negative
import com.ideal.woomanager.ui.theme.Positive
import com.ideal.woomanager.util.Format
import com.ideal.woomanager.util.repoViewModel

@Composable
fun AccountingScreen(currency: String) {
    val vm = repoViewModel { AccountingViewModel(it) }
    val state by vm.state.collectAsState()
    var showDialog by remember { mutableStateOf(false) }

    if (showDialog) {
        AddExpenseDialog(
            onDismiss = { showDialog = false },
            onSave = { vm.addExpense(it); showDialog = false }
        )
    }

    Scaffold(
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { showDialog = true },
                icon = { Icon(Icons.Default.Add, contentDescription = null) },
                text = { Text("ثبت هزینه") }
            )
        }
    ) { padding ->
        Box(Modifier.padding(padding).fillMaxSize()) {
            LazyColumn(Modifier.fillMaxWidth()) {
                item { RangeSelector(selected = state.range, onSelect = vm::setRange) }
                item { Spacer(Modifier.height(8.dp)) }

                // Profit & Loss summary
                item {
                    Card(Modifier.padding(horizontal = 16.dp).fillMaxWidth()) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("صورت سود و زیان", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                            Spacer(Modifier.height(4.dp))
                            PlRow("درآمد کل (فروش ناخالص)", Format.money(state.revenue, currency))
                            PlRow("مالیات دریافتی", Format.money(state.tax, currency), Info)
                            PlRow("حمل و نقل", Format.money(state.shipping, currency), Info)
                            if (state.discount > 0)
                                PlRow("تخفیف‌ها", "- " + Format.money(state.discount, currency), Negative)
                            Divider()
                            PlRow("فروش خالص", Format.money(state.netSales, currency), bold = true)
                            PlRow("مجموع هزینه‌ها", "- " + Format.money(state.totalExpenses, currency), Negative, bold = true)
                            Divider()
                            PlRow(
                                "سود خالص",
                                Format.money(state.netProfit, currency),
                                if (state.netProfit >= 0) Positive else Negative,
                                bold = true
                            )
                        }
                    }
                }

                // Expenses by category
                if (state.expensesByCategory.isNotEmpty()) {
                    item { Spacer(Modifier.height(8.dp)); SectionHeader("هزینه‌ها به تفکیک دسته") }
                    item {
                        Card(Modifier.padding(horizontal = 16.dp).fillMaxWidth()) {
                            Column(Modifier.padding(vertical = 4.dp)) {
                                state.expensesByCategory.forEachIndexed { i, (cat, amt) ->
                                    Row(
                                        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Text(cat, style = MaterialTheme.typography.bodyMedium)
                                        Text(Format.money(amt, currency), fontWeight = FontWeight.SemiBold, color = Negative)
                                    }
                                    if (i < state.expensesByCategory.lastIndex) Divider(Modifier.padding(horizontal = 16.dp))
                                }
                            }
                        }
                    }
                }

                item { Spacer(Modifier.height(8.dp)); SectionHeader("فهرست هزینه‌ها") }
                if (state.expenses.isEmpty()) {
                    item { EmptyState("هزینه‌ای ثبت نشده است", Modifier.height(160.dp)) }
                } else {
                    items(state.expenses) { exp ->
                        Card(Modifier.padding(horizontal = 16.dp, vertical = 4.dp).fillMaxWidth()) {
                            Row(
                                Modifier.padding(start = 16.dp, end = 4.dp, top = 8.dp, bottom = 8.dp).fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(Modifier.weight(1f)) {
                                    Text(exp.title, fontWeight = FontWeight.SemiBold)
                                    Text(
                                        "${exp.category} • ${Format.date(exp.date)}",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    if (exp.note.isNotBlank()) {
                                        Text(exp.note, style = MaterialTheme.typography.labelSmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                                Text(Format.money(exp.amount, currency), color = Negative, fontWeight = FontWeight.Bold)
                                IconButton(onClick = { vm.deleteExpense(exp) }) {
                                    Icon(Icons.Default.Delete, contentDescription = "حذف", tint = Negative)
                                }
                            }
                        }
                    }
                }
                item { Spacer(Modifier.height(80.dp)) }
            }
        }
    }
}

@Composable
private fun PlRow(label: String, value: String, color: Color? = null, bold: Boolean = false) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = if (bold) FontWeight.Bold else FontWeight.Medium,
            color = color ?: MaterialTheme.colorScheme.onSurface
        )
    }
}
