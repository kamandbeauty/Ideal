package com.ideal.woomanager.ui.screens.orders

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.ideal.woomanager.data.model.Order
import com.ideal.woomanager.data.repository.WooRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class OrderDetailState(
    val loading: Boolean = true,
    val error: String? = null,
    val order: Order? = null,
    val updating: Boolean = false,
    val message: String? = null
)

class OrderDetailViewModel(
    private val repo: WooRepository,
    private val orderId: Long
) : ViewModel() {

    private val _state = MutableStateFlow(OrderDetailState())
    val state: StateFlow<OrderDetailState> = _state.asStateFlow()

    init { load() }

    fun load() {
        viewModelScope.launch {
            _state.value = _state.value.copy(loading = true, error = null)
            try {
                val order = repo.getOrder(orderId)
                _state.value = _state.value.copy(loading = false, order = order)
            } catch (e: Exception) {
                _state.value = _state.value.copy(loading = false, error = e.message ?: "خطا")
            }
        }
    }

    fun changeStatus(status: String) {
        viewModelScope.launch {
            _state.value = _state.value.copy(updating = true, message = null)
            try {
                val updated = repo.updateOrderStatus(orderId, status)
                _state.value = _state.value.copy(updating = false, order = updated, message = "وضعیت به‌روزرسانی شد")
            } catch (e: Exception) {
                _state.value = _state.value.copy(updating = false, message = e.message ?: "خطا در به‌روزرسانی")
            }
        }
    }

    fun clearMessage() { _state.value = _state.value.copy(message = null) }
}
