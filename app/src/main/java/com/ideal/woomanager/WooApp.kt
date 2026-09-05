package com.ideal.woomanager

import android.app.Application
import com.ideal.woomanager.data.local.AppDatabase
import com.ideal.woomanager.data.local.SettingsStore
import com.ideal.woomanager.data.repository.WooRepository

class WooApp : Application() {

    lateinit var repository: WooRepository
        private set

    override fun onCreate() {
        super.onCreate()
        val db = AppDatabase.get(this)
        val settings = SettingsStore(this)
        repository = WooRepository(settings, db.expenseDao())
    }
}
