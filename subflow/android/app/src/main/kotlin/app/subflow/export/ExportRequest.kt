package app.subflow.export

/**
 * The renderer's view of one export job.
 *
 * The shape mirrors `CaptionPreset.toMap()` and `SubtitleSegment` in Dart, and
 * Dart is the only writer: the native side never re-decodes the audio or
 * re-reads the database, it just paints the cues it is handed. That keeps this
 * file a data class with no policy in it, and it keeps the "preview == export"
 * rule honest - there is exactly one style object in the app.
 */
internal data class ExportWord(
    val startUs: Long,
    val endUs: Long,
    val text: String,
)

internal data class ExportCue(
    val startUs: Long,
    val endUs: Long,
    val text: String,
    val words: List<ExportWord>,
    /** Set when this caption carries its own style (per-caption customisation). */
    val style: CaptionLook? = null,
)

/**
 * Every field maps 1:1 onto a `CaptionPreset` field. Defaults here are only a
 * safety net for a malformed map; the editor always sends the full object.
 */
internal data class CaptionLook(
    val fontFamily: String = "Vazirmatn",
    val fontWeight: Int = 700,
    val fontScale: Float = 0.062f,
    val textColor: Int = 0xFFFFFFFF.toInt(),
    val accentColor: Int = 0xFF3B82F6.toInt(),
    val strokeWidth: Float = 0f,
    val strokeColor: Int = 0xFF000000.toInt(),
    val shadowBlur: Float = 0f,
    val shadowColor: Int = 0xFF000000.toInt(),
    val shadowOffsetY: Float = 0f,
    val glowRadius: Float = 0f,
    val glowColor: Int = 0xFF000000.toInt(),
    val gradientEnd: Int? = null,
    val boxBackground: Boolean = false,
    val backgroundColor: Int = 0xFF000000.toInt(),
    val backgroundOpacity: Float = 0f,
    val backgroundRadius: Float = 0f,
    val letterSpacing: Float = 0f,
    val lineHeight: Float = 1.15f,
    val positionY: Float = 0.82f,
    val widthFraction: Float = 0.88f,
    val uppercase: Boolean = false,
    val rtl: Boolean = true,
    val enter: String = "none",
    val durationMs: Int = 260,
    val easing: String = "easeOut",
    val intensity: Float = 1f,
    val wordEffect: String = "none",
)

internal data class ExportRequest(
    val uri: String,
    val outputName: String,
    /** Short edge of the output in pixels: 1080, 720 or 480. */
    val maxShortEdge: Int,
    val trimStartUs: Long?,
    val trimEndUs: Long?,
    val look: CaptionLook,
    val cues: List<ExportCue>,
) {
    companion object {
        fun fromMap(map: Map<*, *>): ExportRequest? {
            val uri = map["uri"] as? String ?: return null
            if (uri.isEmpty()) return null
            val cues = (map["cues"] as? List<*>)
                ?.mapNotNull { raw -> cue(raw as? Map<*, *>) }
                ?.sortedBy { it.startUs }
                ?: emptyList()
            return ExportRequest(
                uri = uri,
                outputName = (map["outputName"] as? String)?.takeIf { it.isNotBlank() }
                    ?: "subflow-export.mp4",
                maxShortEdge = (map["maxShortEdge"] as? Number)?.toInt() ?: 1080,
                trimStartUs = (map["trimStartUs"] as? Number)?.toLong(),
                trimEndUs = (map["trimEndUs"] as? Number)?.toLong(),
                look = look(map["style"] as? Map<*, *> ?: emptyMap<String, Any?>()),
                cues = cues,
            )
        }

        private fun cue(map: Map<*, *>?): ExportCue? {
            if (map == null) return null
            val text = (map["text"] as? String) ?: return null
            val start = (map["startUs"] as? Number)?.toLong() ?: return null
            val end = (map["endUs"] as? Number)?.toLong() ?: return null
            if (end <= start) return null
            val cueStyle = (map["style"] as? Map<*, *>)?.let { look(it) }
            val words = (map["words"] as? List<*>)
                ?.mapNotNull { raw ->
                    val word = raw as? Map<*, *> ?: return@mapNotNull null
                    val wordText = word["text"] as? String ?: return@mapNotNull null
                    val wordStart = (word["startUs"] as? Number)?.toLong() ?: return@mapNotNull null
                    val wordEnd = (word["endUs"] as? Number)?.toLong() ?: return@mapNotNull null
                    if (wordEnd <= wordStart) return@mapNotNull null
                    ExportWord(wordStart, wordEnd, wordText)
                }
                ?: emptyList()
            return ExportCue(start, end, text, words, cueStyle)
        }

        private fun look(map: Map<*, *>): CaptionLook {
            fun num(key: String, fallback: Float): Float =
                (map[key] as? Number)?.toFloat() ?: fallback

            fun integer(key: String, fallback: Int): Int =
                (map[key] as? Number)?.toInt() ?: fallback

            fun color(key: String, fallback: Int): Int =
                (map[key] as? Number)?.toLong()?.toInt() ?: fallback

            fun flag(key: String, fallback: Boolean): Boolean =
                map[key] as? Boolean ?: fallback

            fun word(key: String): String =
                (map[key] as? String)?.lowercase() ?: ""

            val effects = map["effects"] as? Map<*, *> ?: emptyMap<String, Any?>()
            fun effectNum(key: String, fallback: Float): Float =
                (effects[key] as? Number)?.toFloat() ?: fallback
            fun effectText(key: String, fallback: String): String =
                (effects[key] as? String)?.lowercase() ?: fallback

            return CaptionLook(
                fontFamily = (map["fontFamily"] as? String) ?: "Vazirmatn",
                fontWeight = integer("fontWeight", 700),
                fontScale = num("fontScale", 0.062f),
                textColor = color("textColor", 0xFFFFFFFF.toInt()),
                accentColor = color("accentColor", 0xFF3B82F6.toInt()),
                strokeWidth = num("strokeWidth", 0f),
                strokeColor = color("strokeColor", 0xFF000000.toInt()),
                shadowBlur = num("shadowBlur", 0f),
                shadowColor = color("shadowColor", 0xFF000000.toInt()),
                shadowOffsetY = num("shadowOffsetY", 0f),
                glowRadius = num("glowRadius", 0f),
                glowColor = color("glowColor", 0xFF000000.toInt()),
                gradientEnd = (map["gradientEnd"] as? Number)?.toLong()?.toInt(),
                boxBackground = flag("boxBackground", false),
                backgroundColor = color("backgroundColor", 0xFF000000.toInt()),
                backgroundOpacity = num("backgroundOpacity", 0f),
                backgroundRadius = num("backgroundRadius", 0f),
                letterSpacing = num("letterSpacing", 0f),
                lineHeight = num("lineHeight", 1.15f).coerceIn(0.8f, 3f),
                positionY = num("positionY", 0.82f).coerceIn(0f, 1f),
                widthFraction = num("widthFraction", 0.88f).coerceIn(0.2f, 1f),
                uppercase = flag("uppercase", false),
                rtl = word("language") != "en",
                enter = effectText("enter", "none"),
                durationMs = (effects["durationMs"] as? Number)?.toInt() ?: 260,
                easing = effectText("easing", "easeOut"),
                intensity = effectNum("intensity", 1f),
                wordEffect = effectText("word", "none"),
            )
        }
    }
}
