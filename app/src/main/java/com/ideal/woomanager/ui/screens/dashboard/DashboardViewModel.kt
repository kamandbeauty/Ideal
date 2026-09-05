package com.ideal.woomanager.ui.screens.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.ideal.woomanager.data.model.Order
import com.ideal.woomanager.data.model.SalesReport
import com.ideal.woomanager.data.model.TopSeller
import com.ideal.woomanager.data.repository.WooRepository
import com.ideal.woomanager.util.DateRange
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

data class DashboardState(
    val loading: Boolean = true,
    val error: String? = null,
    val configured: Boolean = true,
    val range: DateRange = DateRange.MONTH,
    val report: SalesReport = SalesReport(),
    val expenses: Double = 0.0,
    val topSellers: List<TopSeller> = emptyList(),
    val recentOrders: List<Order> = emptyList()
) {
    val revenue: Double get() = report.totalSales.toDoubleOrNull() ?: 0.0
    val netSales: Double get() = report.netSales.toDoubleOrNull() ?: 0.0
    val tax: Double get() = report.totalTax.toDoubleOrNull() ?: 0.0
    val shipping: Double get() = report.totalShipping.toDoubleOrNull() ?: 0.0
    /** Simple net profit estimate: net sales - expenses. */
    val profit: Double get() = netSales - expenses
}

class DashboardViewModel(private val repo: WooRepository) : ViewModel() {

    private val _state = MutableStateFlow(DashboardState())
    val state: StateFlow<DashboardState> = _state.asStateFlow()

    init { load() }

    fun setRange(range: DateRange) {
        _state.value = _state.value.copy(range = range)
        load()
    }

    fun load() {
        viewModelScope.launch {
            val creds = repo.currentCredentials()
            if (!creds.isConfigured) {
                _state.value = _state.value.copy(loading = false, configured = false)
                return@launch
            }
            _state.value = _state.value.copy(loading = true, error = null, configured = true)
            val range = _state.value.range
            try {
                val report = repo.getSalesReport(range)
                val expenses = repo.expensesTotal(range)
                val top = runCatching { repo.getTopSellers(range) }.getOrDefault(emptyList())
                val recent = runCatching { repo.getOrders(perPage = 5) }.getOrDefault(emptyList())
                _state.value = _state.value.copy(
                    loading = false,
                    report = report,
                    expenses = expenses,
                    topSellers = top.take(5),
                    recentOrders = recent
                )
            } catch (e: Exception) {
                _state.value = _state.value.copy(
                    loading = false,
                    error = e.message ?: "خطا در دریافت اطلاعات"
                )
            }
        }
    }
}
