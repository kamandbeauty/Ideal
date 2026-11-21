package ai.javid.app

import ai.javid.app.reminders.ReminderAlarmStore
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The alarm mirror is the only thing that lets a rebooted phone re-arm a
 * reminder before Flutter starts, so its encoding has to round-trip exactly —
 * including Persian text and text containing the field separator.
 */
@RunWith(RobolectricTestRunner::class)
// Pin the SDK: the app targets whatever Flutter ships, which can be newer than
// the newest Robolectric sandbox. SharedPreferences needs nothing from 36.
@Config(sdk = [33])
class ReminderAlarmStoreTest {

    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    private fun entry(id: Int = 7, at: Long = 1_700_000_000_000L) = ReminderAlarmStore.Entry(
        id = id,
        title = "یادآوری جلسه",
        body = "ساعت ۹ با تیم",
        atMillis = at,
    )

    @Test
    fun entryRoundTripsIncludingPersianText() {
        val store = ReminderAlarmStore(context)
        store.replaceAll(emptyList())
        store.upsert(entry())
        val loaded = store.load().single()
        assertEquals(7, loaded.id)
        assertEquals("یادآوری جلسه", loaded.title)
        assertEquals("ساعت ۹ با تیم", loaded.body)
        assertEquals(1_700_000_000_000L, loaded.atMillis)
    }

    @Test
    fun upsertReplacesRatherThanDuplicates() {
        val store = ReminderAlarmStore(context)
        store.replaceAll(emptyList())
        store.upsert(entry(at = 1000L))
        store.upsert(entry(at = 2000L))
        val loaded = store.load()
        assertEquals(1, loaded.size)
        assertEquals(2000L, loaded.single().atMillis)
    }

    @Test
    fun removeDropsOnlyThatAlarm() {
        val store = ReminderAlarmStore(context)
        store.replaceAll(listOf(entry(id = 1), entry(id = 2)))
        store.remove(1)
        assertEquals(listOf(2), store.load().map { it.id })
    }

    @Test
    fun newlinesAndSeparatorsInTextDoNotCorruptTheStore() {
        val store = ReminderAlarmStore(context)
        store.replaceAll(
            listOf(
                ReminderAlarmStore.Entry(3, "a\nb", "c\u001Fd", 42L),
            ),
        )
        val loaded = store.load().single()
        assertEquals(3, loaded.id)
        assertEquals(42L, loaded.atMillis)
        assertTrue("title must not contain a raw newline", !loaded.title.contains("\n"))
        assertEquals("c d", loaded.body)
    }
}
