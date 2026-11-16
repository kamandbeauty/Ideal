package ai.javid.app

import ai.javid.app.notifications.NotificationText
import ai.javid.app.notifications.NotificationSources
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NotificationTextTest {

    @Test
    fun normaliseCollapsesWhitespaceAndNewlines() {
        val raw = "سلام\nدنیا\t   این   یک   پیام است\r\n"
        assertEquals("سلام دنیا این یک پیام است", NotificationText.normalize(raw))
    }

    @Test
    fun normaliseStripsControlCharacters() {
        val raw = "a\u0000b\u0007c"
        assertEquals("abc", NotificationText.normalize(raw))
    }

    @Test
    fun bestBodyPrefersLongerBigText() {
        val body = NotificationText.bestBody(
            text = "کوتاه",
            bigText = "این متن طولانی‌تری است که در حالت BigText می‌آید",
            subText = null,
        )
        assertEquals("این متن طولانی‌تری است که در حالت BigText می‌آید", body)
    }

    @Test
    fun bestBodyFallsBackToSubText() {
        val body = NotificationText.bestBody(text = null, bigText = null, subText = "زیرنویس")
        assertEquals("زیرنویس", body)
    }

    @Test
    fun bestBodyTruncatesToMaximumLength() {
        val body = NotificationText.bestBody(text = "x".repeat(1000), bigText = null, subText = null)
        assertEquals(NotificationText.MAX_TEXT_LENGTH, body.length)
    }

    @Test
    fun dedupeKeyIsStableAndContentSensitive() {
        val first = NotificationText.dedupeKey("com.whatsapp", "علی", "سلام")
        val second = NotificationText.dedupeKey("com.whatsapp", "علی", "سلام")
        val different = NotificationText.dedupeKey("com.whatsapp", "علی", "سلام دیگر")
        assertEquals(first, second)
        assertNotEquals(first, different)
    }

    @Test
    fun classifiesKnownMessagingPackages() {
        assertEquals(NotificationSources.WHATSAPP, NotificationSources.classify("com.whatsapp"))
        assertEquals(NotificationSources.WHATSAPP, NotificationSources.classify("com.whatsapp.w4b"))
        assertEquals(NotificationSources.TELEGRAM, NotificationSources.classify("org.telegram.messenger"))
        assertEquals(NotificationSources.SMS, NotificationSources.classify("com.samsung.android.messaging"))
        assertNull(NotificationSources.classify("com.example.unknown"))
    }
}
