/// Font catalogue for captions.
///
/// Every entry ships inside the APK (no runtime download, product rule #8) and
/// every family has an OFL-1.1 licence file in `assets/fonts/licenses/`.
/// `supportsPersian` is not a guess: it is verified against the font's cmap
/// during review (see `tools/check-project.py`, which fails if a Persian preset
/// points at a Latin-only family).
class CaptionFont {
  const CaptionFont({
    required this.family,
    required this.label,
    required this.license,
    required this.supportsPersian,
    required this.weights,
    this.isDisplay = false,
  });

  /// The exact `family` name declared in pubspec.yaml.
  final String family;

  /// Persian label shown in the picker.
  final String label;
  final String license;

  /// True when the font can shape Arabic/Persian script.
  final bool supportsPersian;
  final List<int> weights;

  /// Display faces (Lalezar, Anton, ...) are not used for long body subtitles.
  final bool isDisplay;
}

class CaptionFonts {
  const CaptionFonts._();

  static const CaptionFont vazirmatn = CaptionFont(
    family: 'Vazirmatn',
    label: 'وزیرمتن',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400, 500, 700, 800],
  );

  static const CaptionFont estedad = CaptionFont(
    family: 'Estedad',
    label: 'استعداد',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400, 700, 800],
  );

  static const CaptionFont sahel = CaptionFont(
    family: 'Sahel',
    label: 'ساحل',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400, 700],
  );

  static const CaptionFont samim = CaptionFont(
    family: 'Samim',
    label: 'صمیم',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400, 700],
    isDisplay: true,
  );

  static const CaptionFont shabnam = CaptionFont(
    family: 'Shabnam',
    label: 'شبنم',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400, 700],
  );

  static const CaptionFont tanha = CaptionFont(
    family: 'Tanha',
    label: 'تنها (تیتر)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400],
    isDisplay: true,
  );

  static const CaptionFont lalezar = CaptionFont(
    family: 'Lalezar',
    label: 'لاله‌زار (تیتر)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400],
    isDisplay: true,
  );

  static const CaptionFont archivoBlack = CaptionFont(
    family: 'Archivo Black',
    label: 'Archivo Black',
    license: 'OFL-1.1',
    supportsPersian: false,
    weights: <int>[400],
    isDisplay: true,
  );

  static const CaptionFont bebasNeue = CaptionFont(
    family: 'Bebas Neue',
    label: 'Bebas Neue',
    license: 'OFL-1.1',
    supportsPersian: false,
    weights: <int>[400],
    isDisplay: true,
  );

  static const CaptionFont anton = CaptionFont(
    family: 'Anton',
    label: 'Anton',
    license: 'OFL-1.1',
    supportsPersian: false,
    weights: <int>[400],
    isDisplay: true,
  );

  // ---------------------------------------------------------------- classics
  // The 14 families below are OFL fonts from Google Fonts, verified against
  // their own cmap for پ چ ژ گ ک ی and Persian digits before being accepted
  // (see `tools/check-project.py`, which repeats the check at build time). That
  // is why fonts such as Tajawal - Arabic-only, no Persian letters - are not
  // part of the catalogue despite looking right in a screenshot.

  static const CaptionFont amiri = CaptionFont(
    family: 'Amiri',
    label: 'امیری (نسخ کلاسیک)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400, 700],
  );

  static const CaptionFont scheherazade = CaptionFont(
    family: 'ScheherazadeNew',
    label: 'شهرزاد (نسخ خوانا)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400, 700],
  );

  static const CaptionFont lateef = CaptionFont(
    family: 'Lateef',
    label: 'لطیف (نسخ)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400, 700],
  );

  static const CaptionFont harmattan = CaptionFont(
    family: 'Harmattan',
    label: 'هرمتان',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400, 700],
  );

  static const CaptionFont almarai = CaptionFont(
    family: 'Almarai',
    label: 'المرعی (هندسی)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400, 700, 800],
  );

  static const CaptionFont ibmPlexArabic = CaptionFont(
    family: 'IBMPlexSansArabic',
    label: 'IBM پلکس (مدرن)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400, 500, 600, 700],
  );

  static const CaptionFont mirza = CaptionFont(
    family: 'Mirza',
    label: 'میرزا (شکسته)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400, 600, 700],
  );

  static const CaptionFont arefRuqaa = CaptionFont(
    family: 'ArefRuqaa',
    label: 'عارف رقعه (خطاطی)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400, 700],
    isDisplay: true,
  );

  static const CaptionFont katibeh = CaptionFont(
    family: 'Katibeh',
    label: 'کتیبه (تیتر)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400],
    isDisplay: true,
  );

  static const CaptionFont jomhuria = CaptionFont(
    family: 'Jomhuria',
    label: 'جمهوریه (تیتر)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400],
    isDisplay: true,
  );

  static const CaptionFont rakkas = CaptionFont(
    family: 'Rakkas',
    label: 'رقاص (تیتر)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400],
    isDisplay: true,
  );

  static const CaptionFont qahiri = CaptionFont(
    family: 'Qahiri',
    label: 'قاهری (کوفی)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400],
    isDisplay: true,
  );

  static const CaptionFont gulzar = CaptionFont(
    family: 'Gulzar',
    label: 'گلزار (نستعلیق)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400],
    isDisplay: true,
  );

  static const CaptionFont vibes = CaptionFont(
    family: 'Vibes',
    label: 'وایبز (تیتر)',
    license: 'OFL-1.1',
    supportsPersian: true,
    weights: <int>[400],
    isDisplay: true,
  );

  static const List<CaptionFont> all = <CaptionFont>[
    vazirmatn,
    estedad,
    sahel,
    samim,
    shabnam,
    tanha,
    lalezar,
    amiri,
    scheherazade,
    lateef,
    harmattan,
    almarai,
    ibmPlexArabic,
    mirza,
    arefRuqaa,
    katibeh,
    jomhuria,
    rakkas,
    qahiri,
    gulzar,
    vibes,
    archivoBlack,
    bebasNeue,
    anton,
  ];

  static List<CaptionFont> persianCapable() =>
      all.where((CaptionFont font) => font.supportsPersian).toList(growable: false);

  static CaptionFont byFamily(String family) => all.firstWhere(
        (CaptionFont font) => font.family == family,
        orElse: () => vazirmatn,
      );
}
