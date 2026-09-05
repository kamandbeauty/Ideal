package com.ideal.woomanager.ui.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.ideal.woomanager.data.local.StoreCredentials
import com.ideal.woomanager.ui.screens.accounting.AccountingScreen
import com.ideal.woomanager.ui.screens.dashboard.DashboardScreen
import com.ideal.woomanager.ui.screens.orders.OrderDetailScreen
import com.ideal.woomanager.ui.screens.orders.OrdersScreen
import com.ideal.woomanager.ui.screens.products.ProductsScreen
import com.ideal.woomanager.ui.screens.settings.SettingsScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppNavigation(credentials: StoreCredentials) {
    val navController = rememberNavController()
    val currency = credentials.currencySymbol.ifBlank { "تومان" }

    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route
    val showBars = currentRoute in bottomItems.map { it.dest.route }

    val currentTitle = bottomItems.firstOrNull { it.dest.route == currentRoute }?.label ?: ""

    Scaffold(
        topBar = {
            if (showBars) {
                TopAppBar(
                    title = { Text(currentTitle, fontWeight = FontWeight.Bold) },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                        titleContentColor = Color.White
                    )
                )
            }
        },
        bottomBar = {
            if (showBars) {
                NavigationBar {
                    val destinations = backStackEntry?.destination
                    bottomItems.forEach { item ->
                        NavigationBarItem(
                            selected = destinations?.hierarchy?.any { it.route == item.dest.route } == true,
                            onClick = {
                                navController.navigate(item.dest.route) {
                                    popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Icon(item.icon, contentDescription = item.label) },
                            label = { Text(item.label, style = MaterialTheme.typography.labelSmall) }
                        )
                    }
                }
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding).fillMaxSize()) {
            NavHost(navController = navController, startDestination = Dest.Dashboard.route) {
                composable(Dest.Dashboard.route) {
                    DashboardScreen(
                        currency = currency,
                        onOpenOrder = { navController.navigate(Dest.OrderDetail.create(it)) },
                        onOpenSettings = { navController.navigate(Dest.Settings.route) }
                    )
                }
                composable(Dest.Orders.route) {
                    OrdersScreen(
                        currency = currency,
                        onOpenOrder = { navController.navigate(Dest.OrderDetail.create(it)) }
                    )
                }
                composable(Dest.Accounting.route) {
                    AccountingScreen(currency = currency)
                }
                composable(Dest.Products.route) {
                    ProductsScreen(currency = currency)
                }
                composable(Dest.Settings.route) {
                    SettingsScreen()
                }
                composable(
                    route = Dest.OrderDetail.route,
                    arguments = listOf(navArgument("orderId") { type = NavType.LongType })
                ) { entry ->
                    val orderId = entry.arguments?.getLong("orderId") ?: 0L
                    OrderDetailScreen(
                        orderId = orderId,
                        currency = currency,
                        onBack = { navController.popBackStack() }
                    )
                }
            }
        }
    }
}
