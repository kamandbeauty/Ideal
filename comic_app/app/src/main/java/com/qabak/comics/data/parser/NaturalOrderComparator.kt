package com.qabak.comics.data.parser

/**
 * Natural alphanumeric comparator for comic archive entries & image filenames.
 * Correctly orders `page_2.jpg` before `page_10.jpg`, supports nested directories,
 * and recognizes ASCII, Persian (۰-۹), and Arabic-Indic (٠-٩) digits without integer overflow.
 */
object NaturalOrderComparator : Comparator<String> {

    override fun compare(a: String?, b: String?): Int {
        if (a === b) return 0
        if (a == null) return -1
        if (b == null) return 1

        val partsA = a.replace('\\', '/').split('/')
        val partsB = b.replace('\\', '/').split('/')
        val minParts = minOf(partsA.size, partsB.size)

        for (p in 0 until minParts) {
            // Keep files in a folder ordered consistently relative to subfolders
            val isDirA = p < partsA.size - 1
            val isDirB = p < partsB.size - 1
            if (isDirA != isDirB) {
                return if (isDirA) 1 else -1
            }
            val segCmp = compareSegment(partsA[p], partsB[p])
            if (segCmp != 0) return segCmp
        }
        return partsA.size.compareTo(partsB.size)
    }

    private fun compareSegment(s1: String, s2: String): Int {
        var i = 0
        var j = 0
        val n1 = s1.length
        val n2 = s2.length

        while (i < n1 && j < n2) {
            val d1 = digitValue(s1[i])
            val d2 = digitValue(s2[j])

            if (d1 >= 0 && d2 >= 0) {
                val start1 = i
                while (i < n1 && digitValue(s1[i]) == 0) i++
                val sigStart1 = i
                while (i < n1 && digitValue(s1[i]) >= 0) i++

                val start2 = j
                while (j < n2 && digitValue(s2[j]) == 0) j++
                val sigStart2 = j
                while (j < n2 && digitValue(s2[j]) >= 0) j++

                val sigLen1 = i - sigStart1
                val sigLen2 = j - sigStart2
                if (sigLen1 != sigLen2) return sigLen1.compareTo(sigLen2)

                for (k in 0 until sigLen1) {
                    val v1 = digitValue(s1[sigStart1 + k])
                    val v2 = digitValue(s2[sigStart2 + k])
                    if (v1 != v2) return v1.compareTo(v2)
                }

                // Tie-break equal numeric values by shorter leading-zero run (e.g. "1" before "01")
                val fullLen1 = i - start1
                val fullLen2 = j - start2
                if (fullLen1 != fullLen2) return fullLen1.compareTo(fullLen2)
            } else {
                val c1 = s1[i].lowercaseChar()
                val c2 = s2[j].lowercaseChar()
                if (c1 != c2) return c1.compareTo(c2)
                i++
                j++
            }
        }
        return (n1 - i).compareTo(n2 - j)
    }

    private fun digitValue(ch: Char): Int = when (ch) {
        in '0'..'9' -> ch - '0'
        in '۰'..'۹' -> ch - '۰'
        in '٠'..'٩' -> ch - '٠'
        else -> -1
    }

    private val IMAGE_EXTENSIONS = setOf("jpg", "jpeg", "png", "webp", "bmp", "gif")

    fun isSupportedImageEntry(entryName: String): Boolean {
        val normalized = entryName.replace('\\', '/').trim()
        if (normalized.isEmpty() || normalized.endsWith('/')) return false
        val segments = normalized.split('/')
        if (segments.any { it.startsWith("__MACOSX") || it.startsWith(".") }) return false
        val fileName = segments.last()
        if (fileName.equals("Thumbs.db", ignoreCase = true)) return false
        val ext = fileName.substringAfterLast('.', "").lowercase()
        return ext in IMAGE_EXTENSIONS
    }
}
