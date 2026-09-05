package com.ideal.woomanager.util

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

object Format {
    private val grouping = java.text.DecimalFormat("#,###")

    fun money(value: Double, symbol: String = "تومان"): String =
        "${grouping.format(value.toLong())} $symbol"

    fun money(value: String, symbol: String = "تومان"): String =
        money(value.toDoubleOrNull() ?: 0.0, symbol)

    fun number(value: Int): String = grouping.format(value.toLong())

    private val isoParsers = listOf(
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd"
    ).map { SimpleDateFormat(it, Locale.US) }

    fun parseIso(value: String?): Long? {
        if (value.isNullOrBlank()) return null
        for (p in isoParsers) {
            try {
                return p.parse(value)?.time
            } catch (_: Exception) { /* try next */ }
        }
        return null
    }

    private val displayFmt = SimpleDateFormat("yyyy/MM/dd HH:mm", Locale.US)
    private val dayFmt = SimpleDateFormat("yyyy/MM/dd", Locale.US)

    fun dateTime(millis: Long?): String =
        if (millis == null) "-" else displayFmt.format(Date(millis))

    fun date(millis: Long?): String =
        if (millis == null) "-" else dayFmt.format(Date(millis))

    fun dateTimeFromIso(iso: String?): String = dateTime(parseIso(iso))
}

/** Common date ranges for reporting. */
enum class DateRange(val label: String) {
    TODAY("امروز"),
    WEEK("۷ روز اخیر"),
    MONTH("این ماه"),
    YEAR("امسال");

    fun bounds(now: Long = System.currentTimeMillis()): Pair<Long, Long> {
        val cal = Calendar.getInstance().apply { timeInMillis = now }
        val end = now
        when (this) {
            TODAY -> cal.setStartOfDay()
            WEEK -> { cal.setStartOfDay(); cal.add(Calendar.DAY_OF_YEAR, -6) }
            MONTH -> { cal.setStartOfDay(); cal.set(Calendar.DAY_OF_MONTH, 1) }
            YEAR -> { cal.setStartOfDay(); cal.set(Calendar.DAY_OF_YEAR, 1) }
        }
        return cal.timeInMillis to end
    }

    /** WooCommerce reports 'date_min'/'date_max' (yyyy-MM-dd). */
    fun wooDates(now: Long = System.currentTimeMillis()): Pair<String, String> {
        val (from, to) = bounds(now)
        val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        return fmt.format(Date(from)) to fmt.format(Date(to))
    }

    private fun Calendar.setStartOfDay() {
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }
}
