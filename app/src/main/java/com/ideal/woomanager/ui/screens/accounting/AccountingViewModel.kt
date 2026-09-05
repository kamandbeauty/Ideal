package com.ideal.woomanager.ui.screens.accounting

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.ideal.woomanager.data.local.Expense
import com.ideal.woomanager.data.model.SalesReport
import com.ideal.woomanager.data.repository.WooRepository
import com.ideal.woomanager.util.DateRange
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

data class AccountingState(
    val loading: Boolean = true,
    val error: String? = null,
    val configured: Boolean = true,
    val range: DateRange = DateRange.MONTH,
    val report: SalesReport = SalesReport(),
    val expenses: List<Expense> = emptyList()
) {
    val revenue: Double get() = report.totalSales.toDoubleOrNull() ?: 0.0
    val netSales: Double get() = report.netSales.toDoubleOrNull() ?: 0.0
    val tax: Double get() = report.totalTax.toDoubleOrNull() ?: 0.0
    val shipping: Double get() = report.totalShipping.toDoubleOrNull() ?: 0.0
    val discount: Double get() = report.totalDiscount.toDoubleOrNull() ?: 0.0
    val totalExpenses: Double get() = expenses.sumOf { it.amount }
    val netProfit: Double get() = netSales - totalExpenses
    val expensesByCategory: List<Pair<String, Double>>
        get() = expenses.groupBy { it.category }
            .map { (cat, list) -> cat to list.sumOf { it.amount } }
            .sortedByDescending { it.second }
}

class AccountingViewModel(private val repo: WooRepository) : ViewModel() {

    private val _state = MutableStateFlow(AccountingState())
    val state: StateFlow<AccountingState> = _state.asStateFlow()

    init {
        observeExpenses()
        loadReport()
    }

    private fun observeExpenses() {
        viewModelScope.launch {
            repo.observeExpenses(_state.value.range).collectLatest { list ->
                _state.value = _state.value.copy(expenses = list)
            }
        }
    }

    fun setRange(range: DateRange) {
        _state.value = _state.value.copy(range = range)
        observeExpenses()
        loadReport()
    }

    fun loadReport() {
        viewModelScope.launch {
            val creds = repo.currentCredentials()
            _state.value = _state.value.copy(loading = true, error = null, configured = creds.isConfigured)
            if (!creds.isConfigured) {
                _state.value = _state.value.copy(loading = false)
                return@launch
            }
            try {
                val report = repo.getSalesReport(_state.value.range)
                _state.value = _state.value.copy(loading = false, report = report)
            } catch (e: Exception) {
                _state.value = _state.value.copy(loading = false, error = e.message)
            }
        }
    }

    fun addExpense(expense: Expense) {
        viewModelScope.launch { repo.addExpense(expense) }
    }

    fun deleteExpense(expense: Expense) {
        viewModelScope.launch { repo.deleteExpense(expense) }
    }
}
