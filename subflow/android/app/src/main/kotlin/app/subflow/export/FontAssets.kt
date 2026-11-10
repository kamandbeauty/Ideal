package app.subflow.export

import android.content.Context
import android.graphics.Typeface
import java.util.Locale

/**
 * Resolves a caption font family to the exact `.ttf` that ships inside the APK.
 *
 * The fonts are declared in `pubspec.yaml` and land in the Flutter asset bundle,
 * so the native renderer reads the *same files* Flutter renders with - no system
 * font fallback, which is what keeps Persian shaping identical in preview and
 * export. The mapping is discovered from the bundle at runtime instead of being
 * duplicated in Kotlin, so adding a font to `pubspec.yaml` cannot silently break
 * the exporter.
 */
internal object FontAssets {

    private const val DIR = "flutter_assets/assets/fonts"
    private val cache = HashMap<String, Typeface>()

    fun resolve(context: Context, family: String, weight: Int): Typeface {
        val key = "$family#$weight"
        synchronized(cache) { cache[key]?.let { return it } }
        val typeface = load(context, family, weight)
            ?: Typeface.create(family, styleFor(weight))
        synchronized(cache) { cache[key] = typeface }
        return typeface
    }

    private fun styleFor(weight: Int): Int = if (weight >= 600) Typeface.BOLD else Typeface.NORMAL

    private fun load(context: Context, family: String, weight: Int): Typeface? {
        val files = runCatching {
            context.assets.list(DIR)?.toList() ?: emptyList()
        }.getOrNull().orEmpty()
        if (files.isEmpty()) return null
        val stem = family.lowercase(Locale.ROOT).replace(" ", "").replace("-", "")
        val candidates = files.filter {
            it.lowercase(Locale.ROOT).endsWith(".ttf") &&
                it.lowercase(Locale.ROOT).replace(" ", "").replace("-", "").startsWith(stem)
        }
        if (candidates.isEmpty()) return null
        val wanted = when {
            weight >= 800 -> listOf("extrabold", "black", "heavy", "bold")
            weight >= 700 -> listOf("bold", "semibold", "extrabold")
            weight >= 500 -> listOf("medium", "regular", "bold")
            else -> listOf("regular", "book", "light", "medium")
        }
        val picked = wanted.firstNotNullOfOrNull { suffix ->
            candidates.firstOrNull { it.lowercase(Locale.ROOT).contains(suffix) }
        } ?: candidates.first()
        return runCatching {
            Typeface.createFromAsset(context.assets, "$DIR/$picked")
        }.getOrNull()
    }
}
