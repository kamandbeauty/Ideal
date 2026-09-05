package com.ideal.woomanager.ui.screens.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import com.ideal.woomanager.data.local.StoreCredentials
import com.ideal.woomanager.util.repoViewModel

@Composable
fun SettingsScreen() {
    val vm = repoViewModel { SettingsViewModel(it) }
    val creds by vm.credentials.collectAsState()
    val testState by vm.testState.collectAsState()
    val saved by vm.saved.collectAsState()

    var baseUrl by remember(creds) { mutableStateOf(creds.baseUrl) }
    var ck by remember(creds) { mutableStateOf(creds.consumerKey) }
    var cs by remember(creds) { mutableStateOf(creds.consumerSecret) }
    var currency by remember(creds) { mutableStateOf(creds.currencySymbol) }
    var showSecret by remember { mutableStateOf(false) }

    LaunchedEffect(saved) {
        if (saved) vm.acknowledgeSaved()
    }

    fun current() = StoreCredentials(baseUrl, ck, cs, currency)

    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("اتصال به فروشگاه ووکامرس", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)

        Card {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = baseUrl,
                    onValueChange = { baseUrl = it },
                    label = { Text("آدرس سایت (مثال: https://shop.com)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = ck,
                    onValueChange = { ck = it },
                    label = { Text("Consumer Key (ck_...)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = cs,
                    onValueChange = { cs = it },
                    label = { Text("Consumer Secret (cs_...)") },
                    singleLine = true,
                    visualTransformation = if (showSecret) VisualTransformation.None else PasswordVisualTransformation(),
                    trailingIcon = {
                        IconButton(onClick = { showSecret = !showSecret }) {
                            Icon(
                                if (showSecret) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                contentDescription = null
                            )
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = currency,
                    onValueChange = { currency = it },
                    label = { Text("واحد پول (مثال: تومان)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }

        if (testState.message != null) {
            Text(
                testState.message!!,
                color = if (testState.success) Color(0xFF2E7D32) else MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodyMedium
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedButton(
                onClick = { vm.testConnection(current()) },
                enabled = !testState.testing && current().isConfigured,
                modifier = Modifier.weight(1f)
            ) {
                if (testState.testing) {
                    CircularProgressIndicator(Modifier.height(18.dp), strokeWidth = 2.dp)
                } else Text("تست اتصال")
            }
            Button(
                onClick = { vm.save(current()) },
                enabled = current().isConfigured,
                modifier = Modifier.weight(1f)
            ) { Text("ذخیره") }
        }

        Spacer(Modifier.height(8.dp))
        HelpCard()
    }
}

@Composable
private fun HelpCard() {
    Card {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("راهنمای دریافت کلید API", fontWeight = FontWeight.Bold)
            Text(
                "۱) وارد پیشخوان وردپرس شوید.\n" +
                    "۲) به ووکامرس ← تنظیمات ← پیشرفته ← REST API بروید.\n" +
                    "۳) روی «افزودن کلید» بزنید و دسترسی را «خواندن/نوشتن» انتخاب کنید.\n" +
                    "۴) Consumer Key و Consumer Secret تولیدشده را اینجا وارد کنید.\n\n" +
                    "توجه: سایت باید روی HTTPS باشد تا احراز هویت به‌درستی کار کند.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
