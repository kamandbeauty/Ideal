package com.qabak.comics

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.qabak.comics.data.local.PreferencesRepository
import com.qabak.comics.data.local.QabakDatabase
import com.qabak.comics.data.parser.BundledPageSource
import com.qabak.comics.data.parser.CbrPageSource
import com.qabak.comics.data.parser.CbzPageSource
import com.qabak.comics.data.parser.ComicInfoXmlParser
import com.qabak.comics.data.parser.NaturalOrderComparator
import com.qabak.comics.data.parser.PanelDetector
import com.qabak.comics.data.parser.UnsupportedRar5Exception
import com.qabak.comics.data.repository.ComicRepository
import com.qabak.comics.model.AppLanguage
import com.qabak.comics.ui.i18n.localizeDigits
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ComicParserAndRepositoryTest {

    @Test
    fun naturalOrderComparator_sortsNumericAndPersianPagesCorrectly() {
        val messy = listOf(
            "page_10.jpg",
            "page_2.jpg",
            "page_01.jpg",
            "page_100.jpg",
            "page_20.jpg"
        )
        val sorted = messy.sortedWith(NaturalOrderComparator)
        assertEquals(
            listOf("page_01.jpg", "page_2.jpg", "page_10.jpg", "page_20.jpg", "page_100.jpg"),
            sorted
        )

        val persian = listOf("صفحه_۱۰.webp", "صفحه_۲.webp", "صفحه_۱.webp")
        assertEquals(
            listOf("صفحه_۱.webp", "صفحه_۲.webp", "صفحه_۱۰.webp"),
            persian.sortedWith(NaturalOrderComparator)
        )

        assertFalse(NaturalOrderComparator.isSupportedImageEntry("__MACOSX/._page_01.jpg"))
        assertFalse(NaturalOrderComparator.isSupportedImageEntry(".DS_Store"))
        assertFalse(NaturalOrderComparator.isSupportedImageEntry("folder/Thumbs.db"))
        assertFalse(NaturalOrderComparator.isSupportedImageEntry("ComicInfo.xml"))
        assertTrue(NaturalOrderComparator.isSupportedImageEntry("ch1/Page_01.WEBP"))
    }

    @Test
    fun comicInfoXmlParser_extractsMetadataAndMangaFlag() {
        val xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <ComicInfo>
              <Title>شب‌های البرز</Title>
              <Series>افسانه کهن</Series>
              <Number>3</Number>
              <Writer>کیوان راد</Writer>
              <Genre>Fantasy</Genre>
              <Summary>داستان سفر در کوهستان.</Summary>
              <Manga>YesAndRightToLeft</Manga>
            </ComicInfo>
        """.trimIndent()

        val info = ComicInfoXmlParser.parse(ByteArrayInputStream(xml.toByteArray(Charsets.UTF_8)))
        assertNotNull(info)
        assertEquals("شب‌های البرز", info!!.title)
        assertEquals("افسانه کهن", info.series)
        assertEquals("3", info.number)
        assertEquals("کیوان راد", info.writer)
        assertEquals("Fantasy", info.genre)
        assertTrue(info.isMangaRtl)
    }

    @Test
    fun cbzPageSource_readsSortedImagesSkipsJunkAndDecodesBitmaps() = runBlocking {
        val tmp = File.createTempFile("sample_test", ".cbz")
        try {
            val colors = listOf(
                "page_10.png" to Color.BLUE,
                "page_2.png" to Color.GREEN,
                "page_1.png" to Color.RED
            )
            ZipOutputStream(FileOutputStream(tmp)).use { zos ->
                // Junk entry that must be skipped
                zos.putNextEntry(ZipEntry("__MACOSX/._page_1.png"))
                zos.write(byteArrayOf(1, 2, 3))
                zos.closeEntry()

                // ComicInfo.xml
                zos.putNextEntry(ZipEntry("ComicInfo.xml"))
                zos.write("<ComicInfo><Title>Test Issue</Title><Manga>Yes</Manga></ComicInfo>".toByteArray())
                zos.closeEntry()

                for ((name, col) in colors) {
                    val bmp = Bitmap.createBitmap(120, 180, Bitmap.Config.ARGB_8888)
                    Canvas(bmp).drawColor(col)
                    zos.putNextEntry(ZipEntry(name))
                    bmp.compress(Bitmap.CompressFormat.PNG, 100, zos)
                    zos.closeEntry()
                }
            }

            CbzPageSource(tmp).use { src ->
                assertEquals(3, src.pageCount)
                val meta = src.readComicInfo()
                assertEquals("Test Issue", meta?.title)
                assertTrue(meta?.isMangaRtl == true)

                // page 0 should be page_1.png (RED), page 1 -> GREEN, page 2 -> BLUE
                val p0 = src.renderPage(0, 200, 300)
                val p1 = src.renderPage(1, 200, 300)
                val p2 = src.renderPage(2, 200, 300)
                assertNotNull(p0)
                assertNotNull(p1)
                assertNotNull(p2)
                assertEquals(Color.RED, p0!!.getPixel(60, 90))
                assertEquals(Color.GREEN, p1!!.getPixel(60, 90))
                assertEquals(Color.BLUE, p2!!.getPixel(60, 90))
            }
        } finally {
            tmp.delete()
        }
    }

    @Test(expected = UnsupportedRar5Exception::class)
    fun cbrPageSource_detectsRar5SignatureCleanly() {
        val tmp = File.createTempFile("rar5_test", ".cbr")
        try {
            tmp.writeBytes(byteArrayOf(0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00, 0x00))
            assertTrue(CbrPageSource.isRar5Archive(tmp))
            CbrPageSource(tmp).close()
        } finally {
            tmp.delete()
        }
    }

    @Test
    fun panelDetector_findsMultiPanelLayoutInRtlAndLtrOrder() {
        val w = 600
        val h = 900
        val page = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(page)
        canvas.drawColor(Color.WHITE) // crisp white gutters
        val paint = Paint().apply { style = Paint.Style.FILL }

        // Top wide panel
        paint.color = Color.rgb(30, 55, 110)
        canvas.drawRect(24f, 24f, 576f, 410f, paint)
        // Bottom-left panel
        paint.color = Color.rgb(120, 40, 50)
        canvas.drawRect(24f, 440f, 286f, 876f, paint)
        // Bottom-right panel
        paint.color = Color.rgb(35, 95, 70)
        canvas.drawRect(314f, 440f, 576f, 876f, paint)

        val rtlPanels = PanelDetector.detectPanels(page, rtlOrder = true)
        assertEquals(3, rtlPanels.size)
        // In RTL, panel[1] is the right-hand panel (centerX > 0.5) and panel[2] is left-hand (< 0.5)
        assertTrue(rtlPanels[1].centerX > rtlPanels[2].centerX)

        val ltrPanels = PanelDetector.detectPanels(page, rtlOrder = false)
        assertEquals(3, ltrPanels.size)
        assertTrue(ltrPanels[1].centerX < ltrPanels[2].centerX)
    }

    @Test
    fun repository_seedsAllBundledComicsBookmarksProgressAndExportsCbz() = runBlocking {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val db = Room.inMemoryDatabaseBuilder(context, QabakDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        val dsFile = File(context.cacheDir, "test_prefs_${System.nanoTime()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
            produceFile = { dsFile }
        )
        val repo = ComicRepository(context, db.comicDao(), db.bookmarkDao(), PreferencesRepository(dataStore))

        try {
            repo.ensureBundledComicsSeeded()
            val comics = repo.comicsFlow.first()
            assertEquals(4, comics.size)

            // Verify every bundled comic's pages render cleanly
            for (comic in comics) {
                BundledPageSource(context, comic.sourcePath).use { src ->
                    assertTrue(src.pageCount >= 5)
                    val firstBmp = src.renderPage(0, 480, 720)
                    assertNotNull("Failed decoding ${comic.id} page 0", firstBmp)
                }
            }

            // Update progress & bookmark with Persian note
            val firstComic = comics.first()
            repo.updateReadingProgress(firstComic.id, 2)
            repo.saveBookmarkWithNote(firstComic.id, 2, "صحنه بیداری نگهبان مفرغی!")

            val updated = repo.getComicOnce(firstComic.id)!!
            assertEquals(2, updated.currentPage)
            assertTrue(updated.isStarted)

            val bms = repo.allBookmarksFlow.first()
            assertEquals(1, bms.size)
            assertEquals("صحنه بیداری نگهبان مفرغی!", bms.first().note)

            // Export as standard CBZ and re-open with CbzPageSource
            val exported = repo.exportComicAsCbz(updated).getOrThrow()
            assertTrue(exported.exists() && exported.length() > 1024L)
            CbzPageSource(exported).use { cbz ->
                assertEquals(updated.pageCount, cbz.pageCount)
                assertNotNull(cbz.readComicInfo()?.title)
            }
        } finally {
            db.close()
            dsFile.delete()
        }
    }

    @Test
    fun persianDigitsLocalization_formatsCleanly() {
        assertEquals("۱۲٫۵", localizeDigits("12.5", AppLanguage.FA))
        assertEquals("۲۰۹۹", localizeDigits("2099", AppLanguage.FA))
        assertEquals("12.5", localizeDigits("12.5", AppLanguage.EN))
    }
}
