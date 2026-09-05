package com.ideal.woomanager.ui.screens.products

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.ideal.woomanager.data.model.Product
import com.ideal.woomanager.data.repository.WooRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ProductsState(
    val loading: Boolean = true,
    val loadingMore: Boolean = false,
    val error: String? = null,
    val configured: Boolean = true,
    val products: List<Product> = emptyList(),
    val search: String = "",
    val page: Int = 1,
    val endReached: Boolean = false
)

class ProductsViewModel(private val repo: WooRepository) : ViewModel() {

    private val _state = MutableStateFlow(ProductsState())
    val state: StateFlow<ProductsState> = _state.asStateFlow()

    private var searchJob: Job? = null

    init { refresh() }

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
            try {
                val products = repo.getProducts(page = 1, search = _state.value.search.ifBlank { null })
                _state.value = _state.value.copy(loading = false, products = products, endReached = products.size < 20)
            } catch (e: Exception) {
                _state.value = _state.value.copy(loading = false, error = e.message ?: "خطا در دریافت محصولات")
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
                val more = repo.getProducts(page = next, search = s.search.ifBlank { null })
                _state.value = _state.value.copy(
                    loadingMore = false,
                    products = _state.value.products + more,
                    page = next,
                    endReached = more.size < 20
                )
            } catch (e: Exception) {
                _state.value = _state.value.copy(loadingMore = false, error = e.message)
            }
        }
    }
}
