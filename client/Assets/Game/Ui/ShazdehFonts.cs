using TMPro;
using UnityEngine;

namespace Shazdeh.Game.Ui
{
    /// <summary>
    /// Where the font comes from.
    ///
    /// The game ships no font binary: a Persian font is a licensed asset and this repository does not
    /// vendor one. Instead there is one expected resource path and a menu item that builds it:
    ///
    ///   1. put a Persian font with Arabic Presentation Forms into Assets/Fonts/ (Vazirmatn is SIL OFL
    ///      and is the one the design was drawn against), and
    ///   2. menu **کاخ شازده → Build UI font** (Shazdeh.EditorTools.TmpFontSetup.Build), which writes
    ///      Assets/Game/Resources/fonts/shazdeh-ui.asset from it.
    ///
    /// Until that exists, labels fall back to whatever TMP calls the default font. That is good enough
    /// to see the layout and it looks wrong in Persian, which is exactly the state the log message says.
    /// </summary>
    public static class ShazdehFonts
    {
        public const string ResourcePath = "fonts/shazdeh-ui";

        static TMP_FontAsset _ui;
        static bool _lookedUp;
        static bool _warned;

        public static TMP_FontAsset Ui
        {
            get
            {
                if (_lookedUp) return _ui;
                _lookedUp = true;

                _ui = Resources.Load<TMP_FontAsset>(ResourcePath);

                if (_ui == null)
                {
                    _ui = TryDefaultFont();
                    WarnOnce();
                }

                return _ui;
            }
        }

        public static bool IsPersianFontInstalled => Resources.Load<TMP_FontAsset>(ResourcePath) != null;

        static TMP_FontAsset TryDefaultFont()
        {
            try
            {
                return TMP_Settings.defaultFontAsset;
            }
            catch
            {
                return null; // TMP essentials were never imported
            }
        }

        static void WarnOnce()
        {
            if (_warned) return;
            _warned = true;

            Debug.LogWarning(
                "[font] " + ResourcePath + " not found. Persian will render with unshaped or missing " +
                "glyphs until you add a font: put a Persian TTF in Assets/Fonts/ and run " +
                "کاخ شازده → Build UI font. See docs/ui.md.");
        }

        /// <summary>For the editor tools and tests: forget the cached lookup.</summary>
        public static void ResetCache()
        {
            _ui = null;
            _lookedUp = false;
            _warned = false;
        }
    }
}
