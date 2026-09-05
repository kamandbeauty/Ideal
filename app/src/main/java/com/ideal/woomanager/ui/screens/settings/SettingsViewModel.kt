package com.ideal.woomanager.ui.screens.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.ideal.woomanager.data.local.StoreCredentials
import com.ideal.woomanager.data.repository.WooRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class TestState(
    val testing: Boolean = false,
    val message: String? = null,
    val success: Boolean = false
)

class SettingsViewModel(private val repo: WooRepository) : ViewModel() {

    val credentials: StateFlow<StoreCredentials> =
        repo.credentialsFlow.stateIn(
            viewModelScope,
            SharingStarted.WhileSubscribed(5000),
            StoreCredentials()
        )

    private val _testState = MutableStateFlow(TestState())
    val testState: StateFlow<TestState> = _testState.asStateFlow()

    private val _saved = MutableStateFlow(false)
    val saved: StateFlow<Boolean> = _saved.asStateFlow()

    fun save(creds: StoreCredentials) {
        viewModelScope.launch {
            repo.saveCredentials(creds)
            _saved.value = true
        }
    }

    fun acknowledgeSaved() { _saved.value = false }

    fun testConnection(creds: StoreCredentials) {
        viewModelScope.launch {
            _testState.value = TestState(testing = true)
            val result = repo.testConnection(creds)
            _testState.value = result.fold(
                onSuccess = { TestState(message = "اتصال موفق بود ✓", success = true) },
                onFailure = { TestState(message = it.message ?: "اتصال ناموفق", success = false) }
            )
        }
    }

    fun clearTest() { _testState.value = TestState() }
}
