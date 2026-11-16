package ai.javid.app.notifications

/**
 * Pure text helpers for notification capture.
 *
 * Extracted from the service so they can be unit-tested on the JVM without an
 * Android device: normalising whitespace, trimming, and building a stable
 * deduplication key.
 */
object NotificationText {

    const val MAX_TEXT_LENGTH = 400

    /** Chooses the richer of the summary/big-text/plain-text fields. */
    fun bestBody(
        text: CharSequence?,
        bigText: CharSequence?,
        subText: CharSequence?,
    ): String {
        val plain = text?.toString()?.trim().orEmpty()
        val big = bigText?.toString()?.trim().orEmpty()
        val sub = subText?.toString()?.trim().orEmpty()
        val chosen = when {
            big.length > plain.length -> big
            plain.isNotEmpty() -> plain
            else -> sub
        }
        return normalize(chosen).take(MAX_TEXT_LENGTH)
    }

    /** Collapses whitespace/newlines and strips control characters. */
    fun normalize(raw: String): String {
        val builder = StringBuilder(raw.length)
        var lastWasSpace = false
        for (character in raw) {
            when {
                character == '\n' || character == '\r' || character == '\t' || character == ' ' -> {
                    if (!lastWasSpace) {
                        builder.append(' ')
                        lastWasSpace = true
                    }
                }
                character.isISOControl() -> Unit
                else -> {
                    builder.append(character)
                    lastWasSpace = false
                }
            }
        }
        return builder.toString().trim()
    }

    /**
     * Stable dedupe key for a notification. Uses the *content*, not the time, so
     * a re-posted identical notification is stored once, while two different
     * messages from the same sender are kept.
     */
    fun dedupeKey(packageName: String, sender: String, body: String): String {
        val raw = "$packageName|$sender|$body"
        return raw.hashCode().toUInt().toString(16)
    }
}
