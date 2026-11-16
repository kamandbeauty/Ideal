package com.qabak.comics.data.parser

import com.qabak.comics.model.ComicInfoMetadata
import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.io.InputStream
import java.io.InputStreamReader

/**
 * Parses standard ComicRack / Kavita / Mihon `ComicInfo.xml` metadata embedded in CBZ & CBR archives.
 */
object ComicInfoXmlParser {

    fun parse(inputStream: InputStream): ComicInfoMetadata? {
        return runCatching {
            val factory = XmlPullParserFactory.newInstance().apply {
                isNamespaceAware = false
            }
            val parser = factory.newPullParser()
            parser.setInput(InputStreamReader(inputStream, Charsets.UTF_8))

            var title: String? = null
            var series: String? = null
            var number: String? = null
            var writer: String? = null
            var penciller: String? = null
            var summary: String? = null
            var genre: String? = null
            var manga: String? = null
            var currentTag: String? = null

            var event = parser.eventType
            while (event != XmlPullParser.END_DOCUMENT) {
                when (event) {
                    XmlPullParser.START_TAG -> currentTag = parser.name
                    XmlPullParser.TEXT -> {
                        val text = parser.text?.trim().orEmpty()
                        if (text.isNotEmpty() && currentTag != null) {
                            when (currentTag.lowercase()) {
                                "title" -> title = text
                                "series" -> series = text
                                "number" -> number = text
                                "writer" -> writer = text
                                "penciller" -> penciller = text
                                "summary" -> summary = text
                                "genre" -> genre = text
                                "manga" -> manga = text
                            }
                        }
                    }
                    XmlPullParser.END_TAG -> currentTag = null
                }
                event = parser.next()
            }

            val author = writer?.takeIf { it.isNotBlank() } ?: penciller?.takeIf { it.isNotBlank() }
            val isManga = manga.equals("Yes", ignoreCase = true) ||
                manga.equals("YesAndRightToLeft", ignoreCase = true)

            ComicInfoMetadata(
                title = title,
                series = series,
                number = number,
                writer = author,
                summary = summary,
                genre = genre,
                isMangaRtl = isManga
            )
        }.getOrNull()
    }
}
