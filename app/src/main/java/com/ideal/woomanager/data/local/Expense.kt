package com.ideal.woomanager.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

/** Local expense/cost entry for accounting (kept on device). */
@Entity(tableName = "expenses")
data class Expense(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val amount: Double,
    val category: String,
    /** epoch millis */
    val date: Long,
    val note: String = ""
)

object ExpenseCategories {
    val all = listOf(
        "خرید کالا",
        "حمل و نقل",
        "بازاریابی و تبلیغات",
        "حقوق و دستمزد",
        "اجاره",
        "قبوض و انرژی",
        "کارمزد درگاه",
        "مالیات",
        "متفرقه"
    )
}
