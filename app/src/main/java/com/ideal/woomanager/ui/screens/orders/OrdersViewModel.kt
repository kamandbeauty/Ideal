package com.ideal.woomanager.ui.screens.orders

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.ideal.woomanager.data.model.Order
import com.ideal.woomanager.data.repository.WooRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class OrdersState(
    val loading: Boolean = true,
    val loadingMore: Boolean = false,
    val error: String? = null,
    val configured: Boolean = true,
    val orders: List<Order> = emptyList(),
    val status: String = "any",
    val search: String = "",
    val page: Int = 1,
    val endReached: Boolean = false
)

class OrdersViewModel(private val repo: WooRepository) : ViewModel() {

    private val _state = MutableStateFlow(OrdersState())
    val state: StateFlow<OrdersState> = _state.asStateFlow()

    private var searchJob: Job? = null

    init { refresh() }

    fun setStatus(status: String) {
        if (_state.value.status == status) return
        _state.value = _state.value.copy(status = status)
        refresh()
    }

    fun onSearchChange(query: String) {
        _state.value = _state.value.copy(search = query)
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(400)
            refresh()
        }
    }

    fun refresh() {
        viewModelScope.launch {
            val creds = repo.currentCredentials()
            if (!creds.isConfigured) {
                _state.value = _state.value.copy(loading = false, configured = false)
                return@launch
            }
            _state.value = _state.value.copy(loading = true, error = null, page = 1, endReached = false, configured = true)
            val s = _state.value
            try {
                val orders = repo.getOrders(status = s.status, page = 1, search = s.search.ifBlank { null })
                _state.value = _state.value.copy(
                    loading = false,
                    orders = orders,
                    endReached = orders.size < 20
                )
            } catch (e: Exception) {
                _state.value = _state.value.copy(loading = false, error = e.message ?: "خطا در دریافت سفارشات")
            }
        }
    }

    fun loadMore() {
        val s = _state.value
        if (s.loading || s.loadingMore || s.endReached) return
        viewModelScope.launch {
            _state.value = s.copy(loadingMore = true)
            val next = s.page + 1
            try {
                val more = repo.getOrders(status = s.status, page = next, search = s.search.ifBlank { null })
                _state.value = _state.value.copy(
                    loadingMore = false,
                    orders = _state.value.orders + more,
                    page = next,
                    endReached = more.size < 20
                )
            } catch (e: Exception) {
                _state.value = _state.value.copy(loadingMore = false, error = e.message)
            }
        }
    }
}
