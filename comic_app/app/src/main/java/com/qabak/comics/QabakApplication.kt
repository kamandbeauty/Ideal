package com.qabak.comics

import android.app.Application
import com.qabak.comics.data.local.PreferencesRepository
import com.qabak.comics.data.local.QabakDatabase
import com.qabak.comics.data.repository.ComicRepository

class QabakApplication : Application() {

    val database: QabakDatabase by lazy { QabakDatabase.getInstance(this) }
    val preferencesRepository: PreferencesRepository by lazy { PreferencesRepository(this) }
    val comicRepository: ComicRepository by lazy {
        ComicRepository(
            context = this,
            comicDao = database.comicDao(),
            bookmarkDao = database.bookmarkDao(),
            preferences = preferencesRepository
        )
    }
}
