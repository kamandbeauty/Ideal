package com.qabak.comics.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.sp
import com.qabak.comics.R
import com.qabak.comics.model.AppLanguage
import com.qabak.comics.model.AppThemeMode
import com.qabak.comics.ui.i18n.LocalAppStrings
import com.qabak.comics.ui.i18n.stringsFor

// Signature Editorial Comic Palette
val ComicAmber = Color(0xFFFFB703)
val ComicAmberDeep = Color(0xFFD97706)
val ComicCrimson = Color(0xFFEF476F)
val ComicCyan = Color(0xFF38BDF8)
val ComicEmerald = Color(0xFF10B981)
val ComicParchment = Color(0xFFFDF3D0)

private val InkDarkScheme = darkColorScheme(
    primary = ComicAmber,
    onPrimary = Color(0xFF1A1200),
    primaryContainer = Color(0xFF3A2A05),
    onPrimaryContainer = Color(0xFFFFDEA0),
    secondary = ComicCyan,
    onSecondary = Color(0xFF06202E),
    secondaryContainer = Color(0xFF132D42),
    onSecondaryContainer = Color(0xFFBAE6FD),
    tertiary = ComicCrimson,
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFF421424),
    onTertiaryContainer = Color(0xFFFFD9E1),
    background = Color(0xFF0D1017),
    onBackground = Color(0xFFF3F5F9),
    surface = Color(0xFF151924),
    onSurface = Color(0xFFF3F5F9),
    surfaceVariant = Color(0xFF1E2433),
    onSurfaceVariant = Color(0xFFA2ACC0),
    surfaceContainerLowest = Color(0xFF090B10),
    surfaceContainerLow = Color(0xFF121620),
    surfaceContainer = Color(0xFF171C28),
    surfaceContainerHigh = Color(0xFF202737),
    surfaceContainerHighest = Color(0xFF2A3245),
    outline = Color(0xFF343E54),
    outlineVariant = Color(0xFF252D3F),
    error = Color(0xFFF87171),
    onError = Color(0xFF2B0606)
)

private val AmoledDarkScheme = InkDarkScheme.copy(
    background = Color(0xFF000000),
    surface = Color(0xFF0A0C10),
    surfaceVariant = Color(0xFF151821),
    surfaceContainerLowest = Color(0xFF000000),
    surfaceContainerLow = Color(0xFF080A0E),
    surfaceContainer = Color(0xFF0E1118),
    surfaceContainerHigh = Color(0xFF171B26),
    surfaceContainerHighest = Color(0xFF212736),
    outlineVariant = Color(0xFF1B202E)
)

private val WarmPaperLightScheme = lightColorScheme(
    primary = Color(0xFFC26D00),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFFE6B3),
    onPrimaryContainer = Color(0xFF381E00),
    secondary = Color(0xFF0369A1),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFE0F2FE),
    onSecondaryContainer = Color(0xFF082F49),
    tertiary = Color(0xFFD81B60),
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFFFCE4EC),
    onTertiaryContainer = Color(0xFF4A0720),
    background = Color(0xFFF8F4EC),
    onBackground = Color(0xFF161922),
    surface = Color(0xFFFFFFFF),
    onSurface = Color(0xFF161922),
    surfaceVariant = Color(0xFFEDE6D8),
    onSurfaceVariant = Color(0xFF52586A),
    surfaceContainerLowest = Color(0xFFFFFFFF),
    surfaceContainerLow = Color(0xFFFDFBF7),
    surfaceContainer = Color(0xFFF3EEE3),
    surfaceContainerHigh = Color(0xFFEAE2D3),
    surfaceContainerHighest = Color(0xFFE0D7C5),
    outline = Color(0xFFC8BFAE),
    outlineVariant = Color(0xFFE2DACB),
    error = Color(0xFFDC2626),
    onError = Color.White
)

val VazirmatnFontFamily = FontFamily(
    Font(R.font.vazirmatn_regular, FontWeight.Normal),
    Font(R.font.vazirmatn_medium, FontWeight.Medium),
    Font(R.font.vazirmatn_bold, FontWeight.SemiBold),
    Font(R.font.vazirmatn_bold, FontWeight.Bold),
    Font(R.font.vazirmatn_extrabold, FontWeight.ExtraBold)
)

val QabakTypography = Typography(
    headlineMedium = TextStyle(
        fontFamily = VazirmatnFontFamily,
        fontWeight = FontWeight.ExtraBold,
        fontSize = 24.sp,
        lineHeight = 34.sp
    ),
    headlineSmall = TextStyle(
        fontFamily = VazirmatnFontFamily,
        fontWeight = FontWeight.Bold,
        fontSize = 20.sp,
        lineHeight = 30.sp
    ),
    titleLarge = TextStyle(
        fontFamily = VazirmatnFontFamily,
        fontWeight = FontWeight.Bold,
        fontSize = 18.sp,
        lineHeight = 27.sp
    ),
    titleMedium = TextStyle(
        fontFamily = VazirmatnFontFamily,
        fontWeight = FontWeight.Bold,
        fontSize = 15.sp,
        lineHeight = 23.sp
    ),
    titleSmall = TextStyle(
        fontFamily = VazirmatnFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 13.sp,
        lineHeight = 20.sp
    ),
    bodyLarge = TextStyle(
        fontFamily = VazirmatnFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 15.sp,
        lineHeight = 25.sp
    ),
    bodyMedium = TextStyle(
        fontFamily = VazirmatnFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 13.sp,
        lineHeight = 21.sp
    ),
    bodySmall = TextStyle(
        fontFamily = VazirmatnFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 11.5.sp,
        lineHeight = 17.sp
    ),
    labelLarge = TextStyle(
        fontFamily = VazirmatnFontFamily,
        fontWeight = FontWeight.Bold,
        fontSize = 13.sp,
        lineHeight = 19.sp
    ),
    labelMedium = TextStyle(
        fontFamily = VazirmatnFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 11.5.sp,
        lineHeight = 16.sp
    ),
    labelSmall = TextStyle(
        fontFamily = VazirmatnFontFamily,
        fontWeight = FontWeight.Bold,
        fontSize = 10.sp,
        lineHeight = 14.sp
    )
)

fun parseHexColor(hex: String, fallback: Color = ComicAmber): Color {
    return runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(fallback)
}

@Composable
fun QabakTheme(
    themeMode: AppThemeMode = AppThemeMode.DARK,
    language: AppLanguage = AppLanguage.FA,
    content: @Composable () -> Unit
) {
    val colorScheme = when (themeMode) {
        AppThemeMode.DARK -> InkDarkScheme
        AppThemeMode.LIGHT -> WarmPaperLightScheme
        AppThemeMode.AMOLED -> AmoledDarkScheme
    }
    val strings = stringsFor(language)
    val layoutDirection = if (language.isRtl) LayoutDirection.Rtl else LayoutDirection.Ltr

    CompositionLocalProvider(
        LocalAppStrings provides strings,
        LocalLayoutDirection provides layoutDirection
    ) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = QabakTypography,
            content = content
        )
    }
}
