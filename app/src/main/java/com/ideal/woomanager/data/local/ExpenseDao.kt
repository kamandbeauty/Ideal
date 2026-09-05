package com.ideal.woomanager.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface ExpenseDao {
    @Query("SELECT * FROM expenses ORDER BY date DESC")
    fun observeAll(): Flow<List<Expense>>

    @Query("SELECT * FROM expenses WHERE date BETWEEN :from AND :to ORDER BY date DESC")
    fun observeBetween(from: Long, to: Long): Flow<List<Expense>>

    @Query("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE date BETWEEN :from AND :to")
    suspend fun sumBetween(from: Long, to: Long): Double

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(expense: Expense): Long

    @Update
    suspend fun update(expense: Expense)

    @Delete
    suspend fun delete(expense: Expense)
}
