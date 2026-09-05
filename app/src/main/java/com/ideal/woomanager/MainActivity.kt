package com.ideal.woomanager

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.runtime.CompositionLocalProvider
import com.ideal.woomanager.data.local.SettingsStore
import com.ideal.woomanager.data.local.StoreCredentials
import com.ideal.woomanager.ui.navigation.AppNavigation
import com.ideal.woomanager.ui.theme.IdealTheme
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.SharingStarted
import androidx.lifecycle.lifecycleScope

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val settings = SettingsStore(this)
        val credsFlow = settings.credentials.stateIn(
            lifecycleScope,
            SharingStarted.Eagerly,
            StoreCredentials()
        )

        setContent {
            IdealTheme {
                // Whole app is Right-to-Left (Persian UI)
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                    val credentials by credsFlow.collectAsState()
                    Surface(modifier = Modifier.fillMaxSize()) {
                        AppNavigation(credentials = credentials)
                    }
                }
            }
        }
    }
}
