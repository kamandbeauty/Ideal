package com.ideal.woomanager.data.repository

import com.ideal.woomanager.data.local.Expense
import com.ideal.woomanager.data.local.ExpenseDao
import com.ideal.woomanager.data.local.SettingsStore
import com.ideal.woomanager.data.local.StoreCredentials
import com.ideal.woomanager.data.model.Order
import com.ideal.woomanager.data.model.Product
import com.ideal.woomanager.data.model.SalesReport
import com.ideal.woomanager.data.model.TopSeller
import com.ideal.woomanager.data.remote.ApiClient
import com.ideal.woomanager.data.remote.WooApi
import com.ideal.woomanager.util.DateRange
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import retrofit2.Response

class WooRepository(
    private val settingsStore: SettingsStore,
    private val expenseDao: ExpenseDao
) {
    val credentialsFlow: Flow<StoreCredentials> = settingsStore.credentials

    suspend fun currentCredentials(): StoreCredentials = settingsStore.credentials.first()

    suspend fun saveCredentials(creds: StoreCredentials) = settingsStore.save(creds)

    private suspend fun api(): WooApi = ApiClient.api(currentCredentials())

    private fun <T> Response<T>.unwrap(): T {
        if (isSuccessful) {
            return body() ?: throw ApiException("پاسخ خالی از سرور")
        }
        val code = code()
        val msg = when (code) {
            401 -> "احراز هویت ناموفق (کلید API را بررسی کنید)"
            403 -> "دسترسی مجاز نیست (۴۰۳)"
            404 -> "آدرس یافت نشد (۴۰۴) — نصب ووکامرس را بررسی کنید"
            else -> "خطای سرور: $code"
        }
        throw ApiException(msg)
    }

    // ---- Orders ----
    suspend fun getOrders(
        status: String? = null,
        page: Int = 1,
        perPage: Int = 20,
        search: String? = null
    ): List<Order> {
        val params = buildMap {
            put("page", page.toString())
            put("per_page", perPage.toString())
            put("orderby", "date")
            put("order", "desc")
            if (!status.isNullOrBlank() && status != "any") put("status", status)
            if (!search.isNullOrBlank()) put("search", search)
        }
        return api().getOrders(params).unwrap()
    }

    suspend fun getOrder(id: Long): Order = api().getOrder(id).unwrap()

    suspend fun updateOrderStatus(id: Long, status: String): Order =
        api().updateOrderStatus(id, mapOf("status" to status)).unwrap()

    // ---- Products ----
    suspend fun getProducts(
        page: Int = 1,
        perPage: Int = 20,
        search: String? = null,
        lowStockOnly: Boolean = false
    ): List<Product> {
        val params = buildMap {
            put("page", page.toString())
            put("per_page", perPage.toString())
            put("orderby", "date")
            put("order", "desc")
            if (!search.isNullOrBlank()) put("search", search)
            if (lowStockOnly) put("stock_status", "outofstock")
        }
        return api().getProducts(params).unwrap()
    }

    // ---- Reports ----
    suspend fun getSalesReport(range: DateRange): SalesReport {
        val (min, max) = range.wooDates()
        val list = api().getSalesReport(
            mapOf("date_min" to min, "date_max" to max)
        ).unwrap()
        return list.firstOrNull() ?: SalesReport()
    }

    suspend fun getTopSellers(range: DateRange): List<TopSeller> {
        val (min, max) = range.wooDates()
        return api().getTopSellers(
            mapOf("date_min" to min, "date_max" to max)
        ).unwrap()
    }

    // ---- Connectivity ----
    suspend fun testConnection(creds: StoreCredentials): Result<Unit> = runCatching {
        val response = ApiClient.api(creds).getOrders(mapOf("per_page" to "1"))
        if (!response.isSuccessful) {
            throw ApiException(
                when (response.code()) {
                    401 -> "کلید API نامعتبر است"
                    404 -> "آدرس یا نصب ووکامرس یافت نشد"
                    else -> "خطا: ${response.code()}"
                }
            )
        }
    }

    // ---- Expenses (local) ----
    fun observeExpenses(): Flow<List<Expense>> = expenseDao.observeAll()

    fun observeExpenses(range: DateRange): Flow<List<Expense>> {
        val (from, to) = range.bounds()
        return expenseDao.observeBetween(from, to)
    }

    suspend fun addExpense(expense: Expense) = expenseDao.insert(expense)
    suspend fun updateExpense(expense: Expense) = expenseDao.update(expense)
    suspend fun deleteExpense(expense: Expense) = expenseDao.delete(expense)
    suspend fun expensesTotal(range: DateRange): Double {
        val (from, to) = range.bounds()
        return expenseDao.sumBetween(from, to)
    }
}

class ApiException(message: String) : Exception(message)
